import RetortTUI

@main
struct HelloApp: App {

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 1) {
                Text("Hello, RetortTUI")
                HStack(spacing: 1) {
                    Text("HStack")
                    Text("+")
                    Text("VStack")
                }
            }
        }
    }
}
