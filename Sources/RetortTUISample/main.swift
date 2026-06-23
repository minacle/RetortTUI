import RetortTUI

@main
struct TextFieldSampleApp: App {

    var body: some Scene {
        WindowGroup {
            TextFieldDemo()
        }
    }
}

private enum Field: Hashable {

    case username

    case email
}

private struct TextFieldDemo: View {

    @State private var username = ""

    @State private var email = ""

    @State private var submitted = "none"

    @FocusState private var focusedField: Field? = .username

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("RetortTUI TextField")
            Text("Focus: \(focusLabel) | Tab switches fields | Return submits | Ctrl-C exits")
            Text("----------------------------------------------------------------")

            HStack(spacing: 1) {
                Text("Username:")
                HStack {
                    Text("[")
                    TextField("username", text: $username, prompt: Text("<required>"))
                        .frame(width: 32)
                        .focused($focusedField, equals: .username)
                        .onSubmit {
                            focusedField = .email
                            submitted = summary
                        }
                    Text("]")
                }
            }

            HStack(spacing: 1) {
                Text("Email:   ")
                HStack {
                    Text("[")
                    TextField("email", text: $email, prompt: Text("<required>"))
                        .frame(width: 32)
                        .focused($focusedField, equals: .email)
                        .onSubmit {
                            submitted = summary
                        }
                    Text("]")
                }
            }

            Text("----------------------------------------------------------------")
            Text("Live username: \(username)")
            Text("Live email:    \(email)")
            Text("Submitted:     \(submitted)")
        }
        .onKeyPress(.tab) {
            switch focusedField {
            case .username:
                focusedField = .email
            case .email, nil:
                focusedField = .username
            }

            return .handled
        }
        .onKeyPress(.escape) {
            focusedField = nil
            return .handled
        }
    }

    private var focusLabel: String {
        switch focusedField {
        case .username:
            return "username"
        case .email:
            return "email"
        case nil:
            return "none"
        }
    }

    private var summary: String {
        "username=\(username), email=\(email)"
    }
}
