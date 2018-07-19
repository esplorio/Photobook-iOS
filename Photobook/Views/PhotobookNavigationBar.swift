//
//  PhotobookNavigationBar.swift
//  Photobook
//
//  Created by Jaime Landazuri on 09/11/2017.
//  Copyright © 2017 Kite.ly. All rights reserved.
//

import UIKit

public class PhotobookNavigationBar: UINavigationBar {
    
    private static let contentHeight: CGFloat = 44.0
    private static let promptHeight: CGFloat = 34.0
    
    private var hasAddedBlur = false
    private var effectView: UIVisualEffectView!
    private(set) var barType: PhotobookNavigationBarType = .white
    
    var willShowPrompt = false {
        didSet {
            if #available(iOS 11.0, *) {
                prefersLargeTitles = !willShowPrompt
            }
        }
    }
    
    var barHeight: CGFloat {
        return willShowPrompt ? PhotobookNavigationBar.contentHeight + PhotobookNavigationBar.promptHeight : PhotobookNavigationBar.contentHeight + UIApplication.shared.statusBarFrame.height
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if !hasAddedBlur {
            hasAddedBlur = true
            
            let effectViewY = willShowPrompt ? 0.0 : -UIApplication.shared.statusBarFrame.height
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            effectView.frame = CGRect(x: 0.0, y: effectViewY, width: bounds.width, height: barHeight)
            effectView.backgroundColor = UIColor(white: 1.0, alpha: 0.75)
            effectView.isUserInteractionEnabled = false
            insertSubview(effectView, at: 0)
        }
        sendSubview(toBack: effectView)
    }
    
    private func setup() {
        barTintColor = .white
        
        if #available(iOS 11.0, *) {
            prefersLargeTitles = true
        }
        
        setBackgroundImage(UIImage(color: .clear), for: .default)
        shadowImage = UIImage()
    }
    
    @objc public func setBarType(_ type: PhotobookNavigationBarType) {
        barType = type
        
        switch barType {
        case .clear:
            barTintColor = .clear
            effectView.alpha = 0.0
        case .white:
            barTintColor = .white
            effectView.alpha = 1.0
        }
    }
}

/// Navigation bar configurations
///
/// - clear: A transparent bar
/// - white: A semi-transparent white tinted bar with a blur effect
@objc public enum PhotobookNavigationBarType: Int {
    case clear, white
}

/// Protocol view controllers should conform to in order to choose an appearance from application defaults when presented
protocol PhotobookNavigationBarDelegate {
    var photobookNavigationBarType: PhotobookNavigationBarType { get }
}

extension PhotobookNavigationBar: UINavigationControllerDelegate {
    
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool){
        
        if let viewController = viewController as? PhotobookNavigationBarDelegate {
            setBarType(viewController.photobookNavigationBarType)
            return
        }
        setBarType(.white)
    }
}
