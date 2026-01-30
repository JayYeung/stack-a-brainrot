//
//  InviteViewController.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import UIKit

final class InviteViewController: UIViewController {
    
    var onInviteCreated: (() -> Void)?
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.text = "Stack a Brainrot"
        return l
    }()
    
    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.text = "Challenge a friend!"
        l.textColor = .secondaryLabel
        return l
    }()
    
    private lazy var inviteButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Invite"
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        let b = UIButton(configuration: config)
        b.addTarget(self, action: #selector(didTapInvite), for: .touchUpInside)
        return b
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        let stack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel, inviteButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    func showSuccess() {
        descriptionLabel.text = "✓ Invite created!\nTap 'Send' then tap the bubble."
    }
    
    @objc private func didTapInvite() {
        onInviteCreated?()
    }
}
