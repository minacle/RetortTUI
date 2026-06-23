import RetortTUI

@main
struct HelloApp: App {

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 1) {
                HStack {
                    Text("RetortTUI")
                    Spacer()
                    Text("Spacer")
                }

                HStack {
                    Text("[leading]")
                    Spacer()
                    Text("[center]")
                    Spacer()
                    Text("[trailing]")
                }
            }
        }
    }
}
