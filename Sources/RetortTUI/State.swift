import Foundation

/// A two-way connection to a value owned by a source of truth.
@dynamicMemberLookup
@propertyWrapper
public struct Binding<Value> {

    private let getValue: () -> Value

    private let setValue: (Value) -> Void

    public var wrappedValue: Value {
        get {
            getValue()
        }
        nonmutating set {
            setValue(newValue)
        }
    }

    public var projectedValue: Binding<Value> {
        self
    }

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getValue = get
        self.setValue = set
    }

    public init(projectedValue: Binding<Value>) {
        self = projectedValue
    }

    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(
            get: { value },
            set: { _ in }
        )
    }

    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        Binding<Subject>(
            get: {
                wrappedValue[keyPath: keyPath]
            },
            set: { newValue in
                var value = wrappedValue
                value[keyPath: keyPath] = newValue
                wrappedValue = value
            }
        )
    }
}

/// A property wrapper type that can read and write a value managed by RetortTUI.
@propertyWrapper
public struct State<Value> {

    private let storage: StateStorage<Value>

    public var wrappedValue: Value {
        get {
            cell.value
        }
        nonmutating set {
            cell.value = newValue
        }
    }

    public var projectedValue: Binding<Value> {
        let cell = cell
        return Binding(
            get: {
                cell.value
            },
            set: { newValue in
                cell.value = newValue
            }
        )
    }

    public init(wrappedValue value: Value) {
        self.storage = StateStorage(initialValue: value)
    }

    public init(initialValue value: Value) {
        self.init(wrappedValue: value)
    }

    private var cell: StateCell<Value> {
        guard let context = StateRenderContext.current else {
            return storage.fallback
        }

        return context.cell(for: storage)
    }
}

public extension State where Value: ExpressibleByNilLiteral {

    init() {
        self.init(wrappedValue: nil)
    }
}

/// A property wrapper type that can read and write the current focus location.
@propertyWrapper
public struct FocusState<Value: Hashable> {

    private let storage: FocusStateStorage<Value>

    public var wrappedValue: Value {
        get {
            cell.value
        }
        nonmutating set {
            cell.setValue(newValue)
        }
    }

    public var projectedValue: Binding {
        Binding(cell: cell)
    }

    public init() {
        guard let value = FocusInitialValue<Value>.value else {
            fatalError("FocusState only supports Bool and Optional values.")
        }

        self.storage = FocusStateStorage(initialValue: value)
    }

    public init(wrappedValue value: Value) {
        guard FocusInitialValue<Value>.value != nil else {
            fatalError("FocusState only supports Bool and Optional values.")
        }

        self.storage = FocusStateStorage(initialValue: value)
    }

    private var cell: FocusCell<Value> {
        guard let context = StateRenderContext.current else {
            return storage.fallback
        }

        return context.focusCell(for: storage)
    }
}

public extension FocusState {

    /// A property wrapper type that can read and write a focus state value.
    @propertyWrapper
    struct Binding {

        fileprivate let cell: FocusCell<Value>

        public var wrappedValue: Value {
            get {
                cell.value
            }
            nonmutating set {
                cell.setValue(newValue)
            }
        }

        public var projectedValue: Binding {
            self
        }

        fileprivate init(cell: FocusCell<Value>) {
            self.cell = cell
        }
    }
}

final class StateRuntime {

    private var cells: [StateKey: Any] = [:]

    private let focus = FocusRuntime()

    private let input = InputRuntime()

    private var textFieldCursors: [[Int]: TextFieldCursor] = [:]

    private var forEachIdentityStates: [ForEachIdentityKey: ForEachIdentityState] = [:]

    private var invalidated = false

    private var focusGeneration = 0

    func block<Content: View>(
        from view: Content,
        in proposal: RenderProposal? = nil
    ) -> RenderedBlock? {
        focus.beginRender()
        input.beginRender()
        defer {
            if focus.finishRender() {
                invalidated = true
            }
        }

        let block = ViewResolver.block(from: view, in: proposal, path: [], runtime: self)
        input.updateHitRegions(block?.hitRegions ?? [])
        return block
    }

    func element<Content: View>(
        from view: Content,
        in proposal: RenderProposal? = nil
    ) -> RenderedElement? {
        focus.beginRender()
        input.beginRender()
        defer {
            if focus.finishRender() {
                invalidated = true
            }
        }

        return ViewResolver.element(from: view, in: proposal, path: [], runtime: self)
    }

    func consumeInvalidation() -> Bool {
        defer {
            invalidated = false
        }

        return invalidated
    }

    fileprivate func cell<Value>(
        for key: StateKey,
        initialValue: @autoclosure () -> Value
    ) -> StateCell<Value> {
        if let cell = cells[key] as? StateCell<Value> {
            return cell
        }

        let cell = StateCell(value: initialValue()) {
            [weak self] in

            self?.invalidated = true
        }
        cells[key] = cell
        return cell
    }

    fileprivate func focusCell<Value: Hashable>(
        for key: StateKey,
        initialValue: @autoclosure () -> Value
    ) -> FocusCell<Value> {
        if let cell = cells[key] as? FocusCell<Value> {
            return cell
        }

        let cell = FocusCell(
            value: initialValue(),
            invalidate: {
                [weak self] in

                self?.invalidated = true
            },
            nextGeneration: {
                [weak self] in

                guard let self else {
                    return 0
                }

                focusGeneration += 1
                return focusGeneration
            }
        )
        cells[key] = cell
        return cell
    }

    func registerFocusable(_ isFocusable: Bool, at path: [Int]) {
        focus.registerFocusable(isFocusable, at: path)
    }

    func registerFocusAttachment(_ attachment: any FocusAttachment, at path: [Int]) {
        focus.registerAttachment(attachment, at: path)
    }

    func registerKeyPressHandler(_ handler: KeyPressHandler, at path: [Int]) {
        input.register(handler, at: path)
    }

    func registerTapGestureHandler(_ handler: TapGestureHandler, at path: [Int]) {
        input.register(handler, at: path)
    }

    func isFocused(at path: [Int]) -> Bool {
        focus.activePath == path
    }

    func textFieldCursor(at path: [Int], initialOffset: Int) -> TextFieldCursor {
        if let cursor = textFieldCursors[path] {
            return cursor
        }

        let cursor = TextFieldCursor(initialOffset: initialOffset) {
            [weak self] in

            self?.invalidated = true
        }
        textFieldCursors[path] = cursor
        return cursor
    }

    func forEachChildIndex(at path: [Int], id: AnyHashable) -> Int {
        let key = ForEachIdentityKey(path: path)
        var state = forEachIdentityStates[key] ?? ForEachIdentityState()

        if let index = state.indicesByID[id] {
            return index
        }

        let index = state.nextIndex
        state.indicesByID[id] = index
        state.nextIndex += 1
        forEachIdentityStates[key] = state
        return index
    }

    func finishForEachRender(at path: [Int], activeIDs: [AnyHashable]) {
        let key = ForEachIdentityKey(path: path)
        guard var state = forEachIdentityStates[key] else {
            return
        }

        let activeIDs = Set(activeIDs)
        let removedPaths = state.indicesByID.compactMap { id, index -> [Int]? in
            activeIDs.contains(id) ? nil : path + [index]
        }
        state.indicesByID = state.indicesByID.filter {
            activeIDs.contains($0.key)
        }
        forEachIdentityStates[key] = state

        for removedPath in removedPaths {
            removeStateSubtree(at: removedPath)
        }
    }

    func dispatch(_ keyPress: KeyPress) -> KeyPress.Result {
        guard let activePath = focus.activePath else {
            return .ignored
        }

        return input.dispatch(keyPress, from: activePath) { path, operation in
            withView(at: path, perform: operation)
        }
    }

    func dispatch(_ mouseEvent: MouseEvent, at date: Date = Date()) -> KeyPress.Result {
        input.dispatch(mouseEvent, at: date) { path, operation in
            withView(at: path, perform: operation)
        }
    }

    var nextTapDeadline: Date? {
        input.nextTapDeadline
    }

    func dispatchExpiredTapActions(at date: Date = Date()) -> KeyPress.Result {
        input.dispatchExpiredTapActions(at: date) { path, operation in
            withView(at: path, perform: operation)
        }
    }

    func updateRenderedFrame(_ frame: TextFrame) {
        input.updateRootFrame(frame)
    }

    func withView<Value>(
        at path: [Int],
        perform operation: () -> Value
    ) -> Value {
        let previous = StateRenderContext.current
        let context = StateRenderContext(runtime: self, path: path)
        StateRenderContext.current = context
        defer {
            StateRenderContext.current = previous
        }

        return operation()
    }

    private func removeStateSubtree(at path: [Int]) {
        cells = cells.filter {
            !$0.key.path.starts(with: path)
        }
        textFieldCursors = textFieldCursors.filter {
            !$0.key.starts(with: path)
        }
        forEachIdentityStates = forEachIdentityStates.filter {
            !$0.key.path.starts(with: path)
        }
    }
}

private final class StateStorage<Value> {

    let initialValue: Value

    let fallback: StateCell<Value>

    var key: StateKey?

    init(initialValue: Value) {
        self.initialValue = initialValue
        self.fallback = StateCell(value: initialValue, invalidate: {})
    }
}

private final class FocusStateStorage<Value: Hashable> {

    let initialValue: Value

    let fallback: FocusCell<Value>

    var key: StateKey?

    init(initialValue: Value) {
        self.initialValue = initialValue
        self.fallback = FocusCell(
            value: initialValue,
            invalidate: {},
            nextGeneration: {
                0
            }
        )
    }
}

private final class StateCell<Value> {

    private let invalidate: () -> Void

    var value: Value {
        didSet {
            invalidate()
        }
    }

    init(value: Value, invalidate: @escaping () -> Void) {
        self.value = value
        self.invalidate = invalidate
    }
}

private final class FocusCell<Value: Hashable> {

    private let invalidate: () -> Void

    private let nextGeneration: () -> Int

    private(set) var value: Value

    private(set) var generation = 0

    init(
        value: Value,
        invalidate: @escaping () -> Void,
        nextGeneration: @escaping () -> Int
    ) {
        self.value = value
        self.invalidate = invalidate
        self.nextGeneration = nextGeneration
    }

    func setValue(
        _ newValue: Value,
        invalidates: Bool = true,
        recordsRequest: Bool = true
    ) {
        guard value != newValue else {
            return
        }

        value = newValue

        if recordsRequest {
            generation = nextGeneration()
        }

        if invalidates {
            invalidate()
        }
    }
}

private enum FocusInitialValue<Value: Hashable> {

    static var value: Value? {
        if Value.self == Bool.self {
            return false as? Value
        }

        return (Value.self as? any OptionalFocusValue.Type)?.nilValue as? Value
    }
}

private protocol OptionalFocusValue {

    static var nilValue: Any { get }
}

extension Optional: OptionalFocusValue {

    fileprivate static var nilValue: Any {
        Self.none as Any
    }
}

private struct StateKey: Hashable {

    enum Kind: Hashable {

        case state

        case focus
    }

    var kind: Kind

    var path: [Int]

    var slot: Int

    var valueType: ObjectIdentifier
}

private struct ForEachIdentityKey: Hashable {

    var path: [Int]
}

private struct ForEachIdentityState {

    var indicesByID: [AnyHashable: Int] = [:]

    var nextIndex = 0
}

private final class StateRenderContext {

    private static let threadKey = "RetortTUI.StateRenderContext"

    let runtime: StateRuntime

    let path: [Int]

    private var nextSlot = 0

    static var current: StateRenderContext? {
        get {
            Thread.current.threadDictionary[threadKey] as? StateRenderContext
        }
        set {
            let dictionary = Thread.current.threadDictionary
            if let newValue {
                dictionary[threadKey] = newValue
            }
            else {
                dictionary.removeObject(forKey: threadKey)
            }
        }
    }

    init(runtime: StateRuntime, path: [Int]) {
        self.runtime = runtime
        self.path = path
    }

    func cell<Value>(for storage: StateStorage<Value>) -> StateCell<Value> {
        let key: StateKey
        if let storedKey = storage.key, storedKey.path == path {
            key = storedKey
            nextSlot = max(nextSlot, storedKey.slot + 1)
        }
        else {
            key = StateKey(
                kind: .state,
                path: path,
                slot: nextSlot,
                valueType: ObjectIdentifier(Value.self)
            )
            storage.key = key
            nextSlot += 1
        }

        return runtime.cell(for: key, initialValue: storage.initialValue)
    }

    func focusCell<Value: Hashable>(
        for storage: FocusStateStorage<Value>
    ) -> FocusCell<Value> {
        let key: StateKey
        if let storedKey = storage.key, storedKey.path == path {
            key = storedKey
            nextSlot = max(nextSlot, storedKey.slot + 1)
        }
        else {
            key = StateKey(
                kind: .focus,
                path: path,
                slot: nextSlot,
                valueType: ObjectIdentifier(Value.self)
            )
            storage.key = key
            nextSlot += 1
        }

        return runtime.focusCell(for: key, initialValue: storage.initialValue)
    }
}

enum StateContext {

    static var currentPath: [Int]? {
        StateRenderContext.current?.path
    }
}

struct FocusRequest: Equatable {

    var bindingID: ObjectIdentifier

    var value: AnyHashable
}

protocol FocusAttachment {

    var bindingID: ObjectIdentifier { get }

    var generation: Int { get }

    func currentRequest() -> FocusRequest?

    func matches(_ request: FocusRequest) -> Bool

    func setActive()

    func clear()
}

private struct BoolFocusAttachment: FocusAttachment {

    let binding: FocusState<Bool>.Binding

    var bindingID: ObjectIdentifier {
        ObjectIdentifier(binding.cell)
    }

    var generation: Int {
        binding.cell.generation
    }

    func currentRequest() -> FocusRequest? {
        guard binding.wrappedValue else {
            return nil
        }

        return FocusRequest(bindingID: bindingID, value: AnyHashable(true))
    }

    func matches(_ request: FocusRequest) -> Bool {
        request.bindingID == bindingID && request.value == AnyHashable(true)
    }

    func setActive() {
        binding.cell.setValue(true, invalidates: false, recordsRequest: false)
    }

    func clear() {
        binding.cell.setValue(false, invalidates: false, recordsRequest: false)
    }
}

private struct OptionalFocusAttachment<Value: Hashable>: FocusAttachment {

    let binding: FocusState<Value?>.Binding

    let value: Value

    var bindingID: ObjectIdentifier {
        ObjectIdentifier(binding.cell)
    }

    var generation: Int {
        binding.cell.generation
    }

    func currentRequest() -> FocusRequest? {
        guard let value = binding.wrappedValue else {
            return nil
        }

        return FocusRequest(bindingID: bindingID, value: AnyHashable(value))
    }

    func matches(_ request: FocusRequest) -> Bool {
        request.bindingID == bindingID && request.value == AnyHashable(value)
    }

    func setActive() {
        binding.cell.setValue(value, invalidates: false, recordsRequest: false)
    }

    func clear() {
        binding.cell.setValue(nil, invalidates: false, recordsRequest: false)
    }
}

extension FocusState.Binding where Value == Bool {

    func focusAttachment() -> any FocusAttachment {
        BoolFocusAttachment(binding: self)
    }
}

extension FocusState.Binding {

    func focusAttachment<Wrapped>(
        equals value: Wrapped
    ) -> any FocusAttachment where Value == Wrapped?, Wrapped: Hashable {
        OptionalFocusAttachment(binding: self, value: value)
    }
}

private final class FocusRuntime {

    private struct Candidate {

        var path: [Int]

        var attachments: [any FocusAttachment]
    }

    private var pathsInRenderOrder: [[Int]] = []

    private var focusablePaths: Set<[Int]> = []

    private var disabledPaths: Set<[Int]> = []

    private var attachmentsByPath: [[Int]: [any FocusAttachment]] = [:]

    private var allAttachments: [any FocusAttachment] = []

    private(set) var activePath: [Int]?

    func beginRender() {
        pathsInRenderOrder = []
        focusablePaths = []
        disabledPaths = []
        attachmentsByPath = [:]
        allAttachments = []
    }

    func registerFocusable(_ isFocusable: Bool, at path: [Int]) {
        registerPath(path)

        if isFocusable {
            focusablePaths.insert(path)
        }
        else {
            focusablePaths.remove(path)
            disabledPaths.insert(path)
        }
    }

    func registerAttachment(_ attachment: any FocusAttachment, at path: [Int]) {
        registerPath(path)
        attachmentsByPath[path, default: []].append(attachment)
        allAttachments.append(attachment)
    }

    func finishRender() -> Bool {
        let candidates = pathsInRenderOrder.compactMap { path -> Candidate? in
            guard focusablePaths.contains(path),
                  !disabledPaths.contains(path),
                  let attachments = attachmentsByPath[path],
                  !attachments.isEmpty else {
                return nil
            }

            return Candidate(path: path, attachments: attachments)
        }

        let previousActivePath = activePath
        activePath = activePath(for: candidates)
        syncAttachments(for: candidates.first { $0.path == activePath })
        return activePath != previousActivePath
    }

    private func activePath(for candidates: [Candidate]) -> [Int]? {
        guard let request = currentRequest() else {
            return nil
        }

        return candidates.first { candidate in
            candidate.attachments.contains {
                $0.matches(request)
            }
        }?.path
    }

    private func currentRequest() -> FocusRequest? {
        allAttachments
            .compactMap { attachment -> (FocusRequest, Int)? in
                attachment.currentRequest().map { ($0, attachment.generation) }
            }
            .max { lhs, rhs in
                lhs.1 < rhs.1
            }?
            .0
    }

    private func syncAttachments(for activeCandidate: Candidate?) {
        var activeBindingIDs = Set<ObjectIdentifier>()
        if let activeCandidate {
            for attachment in activeCandidate.attachments
                where !activeBindingIDs.contains(attachment.bindingID) {
                activeBindingIDs.insert(attachment.bindingID)
                attachment.setActive()
            }
        }

        var clearedBindingIDs = Set<ObjectIdentifier>()
        for attachment in allAttachments
            where !activeBindingIDs.contains(attachment.bindingID)
                && !clearedBindingIDs.contains(attachment.bindingID) {
            clearedBindingIDs.insert(attachment.bindingID)
            attachment.clear()
        }
    }

    private func registerPath(_ path: [Int]) {
        guard !pathsInRenderOrder.contains(path) else {
            return
        }

        pathsInRenderOrder.append(path)
    }
}
