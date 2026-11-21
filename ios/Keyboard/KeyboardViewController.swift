import UIKit
import SwiftUI

/// 键盘主控制器：整个键盘 UI 用 SwiftUI 画，插入文本走 textDocumentProxy
final class KeyboardViewController: UIInputViewController {

    private var host: UIHostingController<KeyboardView>?
    private let model = KeyboardModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupHeight()
        setupUI()
        wire()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 有完全访问才写这个标记，App 里据此判断是否就绪
        if hasFullAccess {
            Cfg.shared.set(true, forKey: Cfg.kFullAccess)
            Cfg.shared.synchronize()
        }
        model.needsFullAccess = !hasFullAccess
        model.refreshConfig()
    }

    private func setupHeight() {
        let h = view.heightAnchor.constraint(equalToConstant: 292)
        h.priority = UILayoutPriority(999)
        h.isActive = true
    }

    private func setupUI() {
        let root = KeyboardView(model: model)
        let h = UIHostingController(rootView: root)
        h.view.backgroundColor = .clear
        addChild(h)
        view.addSubview(h.view)
        h.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            h.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            h.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            h.view.topAnchor.constraint(equalTo: view.topAnchor),
            h.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        h.didMove(toParent: self)
        host = h
    }

    private func wire() {
        model.insert = { [weak self] text in
            guard let self else { return }
            self.textDocumentProxy.insertText(text)
            if text.count > 2 {
                RecordStore.shared.add(text: text, seconds: self.model.lastSeconds, source: "keyboard")
            }
        }
        model.del = { [weak self] in
            self?.textDocumentProxy.deleteBackward()
        }
        model.nextKb = { [weak self] in
            self?.advanceToNextInputMode()
        }
        model.dismiss = { [weak self] in
            self?.dismissKeyboard()
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
    }
}
