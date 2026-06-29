import Testing
import RetortTUI

@Test func retortTUIReexportsSwiftTUITextAPI() {
    let text = Text("Hello")

    #expect(text.content == "Hello")
}

@Test func retortTUIReexportsSwiftTUIStateAPI() {
    var value = "initial"
    let binding = Binding(
        get: {
            value
        },
        set: { newValue in
            value = newValue
        }
    )

    binding.wrappedValue = "updated"

    #expect(value == "updated")
}

@Test func retortTUIReexportsSwiftTUIViewBuilderAPI() {
    let view = SmokeView()

    #expect(view.title.content == "Smoke")
}

private struct SmokeView: View {

    var title: Text {
        Text("Smoke")
    }

    var body: some View {
        VStack(alignment: .leading) {
            title
            Text("Visible through RetortTUI")
                .color(.brightCyan)
                .bold()
        }
    }
}
