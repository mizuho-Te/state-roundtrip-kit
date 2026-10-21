import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = ValidationViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

// This standalone app contains no production store, account, networking, sync, or real data.
// Both fixture argument handling and persistent storage exist only in DEBUG builds.
final class ValidationViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        #if DEBUG
        do { try configureFixture() }
        catch { showMessage("Fixture unavailable", identifier: "roundtrip.isolation-error") }
        #else
        showMessage("DEBUG validation only", identifier: "roundtrip.disabled")
        #endif
    }

    private func showMessage(_ message: String, identifier: String) {
        let label = UILabel()
        label.text = message
        label.accessibilityIdentifier = identifier
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    #if DEBUG
    private struct Card: Codable { let question: String }
    private enum FixtureError: Error { case invalidArguments }
    private var file: URL?
    private let input = UITextField()
    private let saved = UILabel()

    private func configureFixture() throws {
        let arguments = ProcessInfo.processInfo.arguments
        let flags = arguments.indices.filter { arguments[$0] == "--roundtrip-fixture" }
        guard flags.count == 1, let flag = flags.first, flag + 1 < arguments.count else {
            throw FixtureError.invalidArguments
        }
        let id = arguments[flag + 1]
        let prefix = "state-roundtrip-"
        guard id.hasPrefix(prefix),
              let uuid = UUID(uuidString: String(id.dropFirst(prefix.count))),
              id == prefix + uuid.uuidString.lowercased() else { throw FixtureError.invalidArguments }

        let manager = FileManager.default
        let support = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                      appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("StateRoundtripValidation", isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("card.json")
        let restored: String
        if manager.fileExists(atPath: file.path) {
            restored = try JSONDecoder().decode(Card.self, from: Data(contentsOf: file)).question
        } else { restored = "" }
        self.file = file

        let heading = UILabel()
        heading.text = "Synthetic card fixture"
        heading.font = .preferredFont(forTextStyle: .headline)
        let ready = UILabel()
        ready.text = "Isolated fixture ready"
        ready.accessibilityIdentifier = "roundtrip.isolated-ready"
        input.borderStyle = .roundedRect
        input.placeholder = "Enter synthetic question"
        input.text = restored
        input.autocorrectionType = .no
        input.spellCheckingType = .no
        input.accessibilityIdentifier = "card.question"
        input.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        let save = UIButton(type: .system)
        save.setTitle("Save", for: .normal)
        save.accessibilityIdentifier = "card.save"
        save.addTarget(self, action: #selector(saveCard), for: .touchUpInside)
        saved.text = "Saved"
        saved.accessibilityIdentifier = "card.saved"
        saved.isHidden = true
        let stack = UIStackView(arrangedSubviews: [heading, ready, input, save, saved])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            input.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func editingChanged() { saved.isHidden = true }
    @objc private func saveCard() {
        saved.isHidden = true
        guard let file else { return }
        do {
            try JSONEncoder().encode(Card(question: input.text ?? "")).write(to: file, options: .atomic)
            saved.accessibilityValue = UUID().uuidString
            saved.isHidden = false
            input.resignFirstResponder()
        } catch {
            showMessage("Save failed", identifier: "card.save-error")
        }
    }
    #endif
}
