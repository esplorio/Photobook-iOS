//
//  CheckoutViewController.swift
//  Photobook
//
//  Created by Julian Gruber on 16/01/2018.
//  Copyright © 2018 Kite.ly. All rights reserved.
//

import UIKit
import PassKit

class CheckoutViewController: UIViewController {
    
    private struct Constants {
        static let receiptSegueName = "ReceiptSegue"
        
        static let segueIdentifierDeliveryDetails = "segueDeliveryDetails"
        static let segueIdentifierShippingMethods = "segueShippingMethods"
        static let segueIdentifierPaymentMethods = "seguePaymentMethods"
        
        static let detailsLabelColor = UIColor.black
        static let detailsLabelColorRequired = UIColor.red.withAlphaComponent(0.6)
        
        static let loadingDetailsText = NSLocalizedString("Controllers/CheckoutViewController/EmptyScreenLoadingText",
                                                    value: "Loading price details",
                                                    comment: "Info text displayed next to a loading indicator while loading price details")
        static let loadingPaymentText = NSLocalizedString("Controllers/CheckoutViewController/PaymentLoadingText",
                                                   value: "Preparing Payment",
                                                   comment: "Info text displayed while preparing for payment service")
        static let processingText = NSLocalizedString("Controllers/CheckoutViewController/ProcessingText",
                                                          value: "Processing",
                                                          comment: "Info text displayed while processing the order")
        static let submittingOrderText = NSLocalizedString("Controllers/CheckoutViewController/SubmittingOrderText",
                                                          value: "Submitting Order",
                                                          comment: "Info text displayed while submitting order")
        static let labelRequiredText = NSLocalizedString("Controllers/CheckoutViewController/LabelRequiredText",
                                                          value: "Required",
                                                          comment: "Hint on empty but required order text fields if user clicks on pay")
        static let payingWithText = NSLocalizedString("Controllers/CheckoutViewController/PaymentMethodText",
                                                         value: "Paying With",
                                                         comment: "Left side of payment method row if a payment method is selected")
        static let paymentMethodText = NSLocalizedString("Controllers/CheckoutViewController/PaymentMethodRequiredText",
                                                                 value: "Payment Method",
                                                                 comment: "Left side of payment method row if required hint is displayed")
        static let promoCodePlaceholderText = NSLocalizedString("Controllers/CheckoutViewController/PromoCodePlaceholderText",
                                                         value: "Add here",
                                                         comment: "Placeholder text for promo code")
        static let title = NSLocalizedString("Controllers/CheckoutViewController/Title", value: "Payment", comment: "Payment screen title")
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet private weak var promoCodeActivityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var promoCodeLabel: UILabel! {
        didSet {
            if #available(iOS 11.0, *) {
                promoCodeLabel.font = UIFontMetrics.default.scaledFont(for: promoCodeLabel.font)
                promoCodeLabel.adjustsFontForContentSizeCategory = true
            }
        }
    }
    @IBOutlet private weak var promoCodeView: UIView!
    @IBOutlet private weak var promoCodeTextField: UITextField! {
        didSet {
            if #available(iOS 11.0, *), let font = promoCodeTextField.font {
                promoCodeTextField.font = UIFontMetrics.default.scaledFont(for: font)
                promoCodeTextField.adjustsFontForContentSizeCategory = true
            }
        }
    }
    @IBOutlet private weak var promoCodeClearButton: UIButton!
    @IBOutlet private weak var deliveryDetailsView: UIView!
    @IBOutlet private weak var deliveryDetailsLabel: UILabel! {
        didSet {
            if #available(iOS 11.0, *) {
                deliveryDetailsLabel.font = UIFontMetrics.default.scaledFont(for: deliveryDetailsLabel.font)
                deliveryDetailsLabel.adjustsFontForContentSizeCategory = true
            }
        }
    }
    @IBOutlet private weak var shippingMethodView: UIView!
    @IBOutlet private weak var shippingMethodLabel: UILabel! {
        didSet {
            if #available(iOS 11.0, *) {
                shippingMethodLabel.font = UIFontMetrics.default.scaledFont(for: shippingMethodLabel.font)
                shippingMethodLabel.adjustsFontForContentSizeCategory = true
            }
        }
    }
    @IBOutlet private weak var paymentMethodView: UIView!
    @IBOutlet private weak var paymentMethodTitleLabel: UILabel! {
        didSet {
            if #available(iOS 11.0, *) {
                paymentMethodTitleLabel.font = UIFontMetrics.default.scaledFont(for: paymentMethodTitleLabel.font)
                paymentMethodTitleLabel.adjustsFontForContentSizeCategory = true
            }
        }
    }
    @IBOutlet private weak var paymentMethodLabel: UILabel! {
        didSet {
            if #available(iOS 11.0, *) {
                paymentMethodLabel.font = UIFontMetrics.default.scaledFont(for: paymentMethodLabel.font)
                paymentMethodLabel.adjustsFontForContentSizeCategory = true
            }
        }
    }
    @IBOutlet private weak var paymentMethodIconImageView: UIImageView!
    @IBOutlet private weak var payButtonContainerView: UIView!
    @IBOutlet private weak var payButton: UIButton! {
        didSet{
            if #available(iOS 11.0, *) {
                payButton.titleLabel?.font = UIFontMetrics.default.scaledFont(for: payButton.titleLabel!.font)
                payButton.titleLabel?.adjustsFontForContentSizeCategory = true
            }
        }
    }
    @IBOutlet private weak var infoLabelDeliveryDetails: UILabel! {
        didSet {
            if #available(iOS 11.0, *) {
                infoLabelDeliveryDetails.font = UIFontMetrics.default.scaledFont(for: infoLabelDeliveryDetails.font)
                infoLabelDeliveryDetails.adjustsFontForContentSizeCategory = true
            }
        }
    }
    @IBOutlet private weak var infoLabelShipping: UILabel! {
        didSet {
            if #available(iOS 11.0, *) {
                infoLabelShipping.font = UIFontMetrics.default.scaledFont(for: infoLabelShipping.font)
                infoLabelShipping.adjustsFontForContentSizeCategory = true
            }
        }
    }
    
    private var applePayButton: PKPaymentButton?
    private var payButtonOriginalColor: UIColor!

    @IBOutlet var promoCodeDismissGestureRecognizer: UITapGestureRecognizer!
    
    @IBOutlet private weak var hideDeliveryDetailsConstraint: NSLayoutConstraint!
    @IBOutlet private weak var showDeliveryDetailsConstraint: NSLayoutConstraint!
    @IBOutlet private weak var optionsViewBottomContraint: NSLayoutConstraint!
    @IBOutlet private weak var optionsViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var promoCodeViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var promoCodeAccessoryConstraint: NSLayoutConstraint!
    @IBOutlet private weak var promoCodeNormalConstraint: NSLayoutConstraint!
    
    private var previousPromoText: String? // Stores previously entered promo string to determine if it has changed
    private var editingProductIndex: Int?
    
    private var modalPresentationDismissedGroup = DispatchGroup()
    private lazy var isPresentedModally: Bool = { return (navigationController?.isBeingPresented ?? false) || isBeingPresented }()
    private lazy var cancelBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(tappedCancel))
    }()
    lazy private var paymentManager: PaymentAuthorizationManager = {
        let manager = PaymentAuthorizationManager()
        manager.delegate = self
        return manager
    }()
    
    private lazy var progressOverlayViewController: ProgressOverlayViewController = {
        return ProgressOverlayViewController.progressOverlay(parent: self)
    }()
    
    private lazy var emptyScreenViewController: EmptyScreenViewController = {
        return EmptyScreenViewController.emptyScreen(parent: self)
    }()
    
    private var order: Order {
        return OrderManager.shared.basketOrder
    }
    
    weak var dismissDelegate: DismissDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        }
        
        Analytics.shared.trackScreenViewed(.basket)
        
        if APIClient.environment == .test {
            title = Constants.title + " (TEST)"
        } else {
            title = Constants.title
        }
        
        registerForKeyboardNotifications()
        
        // Clear fields
        deliveryDetailsLabel.text = nil
        shippingMethodLabel.text = nil
        paymentMethodLabel.text = nil
        
        promoCodeTextField.placeholder = Constants.promoCodePlaceholderText
        
        payButtonOriginalColor = payButton.backgroundColor
        payButton.addTarget(self, action: #selector(CheckoutViewController.payButtonTapped(_:)), for: .touchUpInside)
        
        // Apple Pay
        if PaymentAuthorizationManager.isApplePayAvailable {
            setupApplePayButton()
        }
        
        if isPresentedModally {
            navigationItem.leftBarButtonItems = [ cancelBarButtonItem ]
        }
        
        emptyScreenViewController.show(message: Constants.loadingDetailsText, activity: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        payButton.titleLabel?.sizeToFit()
    }
    
    private func setupApplePayButton() {
        let applePayButton = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
        applePayButton.translatesAutoresizingMaskIntoConstraints = false
        applePayButton.addTarget(self, action: #selector(payButtonTapped(_:)), for: .touchUpInside)
        self.applePayButton = applePayButton
        payButtonContainerView.addSubview(applePayButton)
        payButtonContainerView.clipsToBounds = true
        payButtonContainerView.cornerRadius = 10
        
        let views: [String: Any] = ["applePayButton": applePayButton]
        
        let vConstraints = NSLayoutConstraint.constraints(
            withVisualFormat: "V:|[applePayButton]|",
            metrics: nil,
            views: views)
        
        let hConstraints = NSLayoutConstraint.constraints(
            withVisualFormat: "H:|[applePayButton]|",
            metrics: nil,
            views: views)
        
        view.addConstraints(hConstraints + vConstraints)
    }
    
    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(notification:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateViews()
        if !order.hasValidCachedCost {
            refresh(showProgress: false)
        } else {
            emptyScreenViewController.hide()
        }
    }
    
    @objc func tappedCancel() {
        if dismissDelegate?.wantsToDismiss?(self) != nil {
            return
        }
        
        // No delegate provided
        presentingViewController?.dismiss(animated: true, completion: nil)
    }

    private func refresh(showProgress: Bool = true, forceCostUpdate: Bool = false, forceShippingMethodsUpdate: Bool = false) {
        if showProgress {
            progressOverlayViewController.show(message: Constants.loadingDetailsText)
        }
        
        order.updateCost(forceUpdate: forceCostUpdate, forceShippingMethodUpdate: forceShippingMethodsUpdate) { [weak welf = self] (error) in
            
            welf?.emptyScreenViewController.hide()
            welf?.progressOverlayViewController.hide()
            welf?.promoCodeActivityIndicator.stopAnimating()
            welf?.promoCodeTextField.isUserInteractionEnabled = true
            
            if let error = error {
                if !(welf?.order.hasCachedCost ?? false) {
                    let errorMessage = ErrorMessage(error)
                    welf?.emptyScreenViewController.show(message: errorMessage.text, title: errorMessage.title)
                    return
                }
                
                guard let stelf = welf else { return }
                MessageBarViewController.show(message: ErrorMessage(error), parentViewController: stelf, offsetTop: stelf.navigationController!.navigationBar.frame.maxY, centred: true) {
                    welf?.refresh(showProgress: showProgress, forceCostUpdate: forceCostUpdate, forceShippingMethodsUpdate: forceShippingMethodsUpdate)
                }
                return
            }
            
            welf?.updateViews()
        }
    }
    
    private func updateProductCell(_ cell: BasketProductTableViewCell, for index: Int) {
        guard let lineItems = order.cost?.lineItems,
            index < lineItems.count
            else {
                return
        }
        let lineItem = lineItems[index]
        let product = order.products[index]
        cell.productDescriptionLabel.text = lineItem.name
        cell.priceLabel.text = lineItem.price.formatted
        cell.itemAmountButton.setTitle("\(product.itemCount)", for: .normal)
        cell.itemAmountButton.accessibilityValue = cell.itemAmountButton.title(for: .normal)
        cell.productIdentifier = product.identifier
        product.previewImage(size: cell.productImageView.frame.size * UIScreen.main.scale, completionHandler: { image in
            guard product.identifier == cell.productIdentifier else {
                return
            }
            
            cell.productImageView.image = image
        })
    }
    
    private func updateViews() {
        
        // Products
        for index in 0..<order.products.count {
            guard let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BasketProductTableViewCell else {
                continue
            }
            updateProductCell(cell, for: index)
        }
        
        // Promo code
        if let promoDiscount = order.cost?.promoDiscount, promoDiscount.value != 0 {
            promoCodeTextField.text = promoDiscount.formatted
            previousPromoText = promoDiscount.formatted
            promoCodeClearButton.isHidden = false
            promoCodeAccessoryConstraint.priority = .defaultHigh
            promoCodeNormalConstraint.priority = .defaultLow
        }
        
        let promoCodeIsInvalid = checkPromoCode()
        
        // Payment Method Icon
        showDeliveryDetailsConstraint.priority = .defaultHigh
        hideDeliveryDetailsConstraint.priority = .defaultLow
        deliveryDetailsView.isHidden = false
        paymentMethodIconImageView.image = nil
        if let paymentMethod = order.paymentMethod {
            switch paymentMethod {
            case .creditCard where Card.currentCard != nil:
                let card = Card.currentCard!
                paymentMethodIconImageView.image = card.cardIcon
                paymentMethodView.accessibilityValue = card.number.cardType()?.stringValue()
                paymentMethodTitleLabel.text = Constants.payingWithText
            case .applePay:
                paymentMethodIconImageView.image = UIImage(namedInPhotobookBundle: "apple-pay-method")
                paymentMethodView.accessibilityValue = "Apple Pay"
                showDeliveryDetailsConstraint.priority = .defaultLow
                hideDeliveryDetailsConstraint.priority = .defaultHigh
                deliveryDetailsView.isHidden = true
                paymentMethodTitleLabel.text = Constants.payingWithText
            case .payPal:
                paymentMethodIconImageView.image = UIImage(namedInPhotobookBundle: "paypal-method")
                paymentMethodView.accessibilityValue = "PayPal"
                paymentMethodTitleLabel.text = Constants.payingWithText
            default:
                order.paymentMethod = nil
            }
            paymentMethodIconImageView.isHidden = false
            paymentMethodLabel.isHidden = true
        }
        
        // Shipping
        shippingMethodLabel.text = ""
        if let cost = order.cost {
            shippingMethodLabel.text = cost.totalShippingPrice.formatted
        }
        
        // Address
        var addressString = ""
        if let address = order.deliveryDetails?.address, let line1 = address.line1 {
            
            addressString = line1
            if let line2 = address.line2, !line2.isEmpty { addressString = addressString + ", " + line2 }
            if let postcode = address.zipOrPostcode, !postcode.isEmpty { addressString = addressString + ", " + postcode }
            if !address.country.name.isEmpty { addressString = addressString + ", " + address.country.name }
            
            //reset view
            deliveryDetailsLabel.textColor = Constants.detailsLabelColor
            deliveryDetailsLabel.text = addressString
        }
        
        // CTA button
        adaptPayButton()
        
        // Accessibility
        deliveryDetailsView.accessibilityLabel = infoLabelDeliveryDetails.text
        deliveryDetailsView.accessibilityValue = deliveryDetailsLabel.text
        
        shippingMethodView.accessibilityLabel = infoLabelShipping.text
        shippingMethodView.accessibilityValue = shippingMethodLabel.text
        
        paymentMethodView.accessibilityLabel = paymentMethodTitleLabel.text
        
        if promoCodeIsInvalid {
            UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, promoCodeTextField)
        }
    }
    
    private func adaptPayButton() {
        // Hide all
        applePayButton?.isHidden = true
        applePayButton?.isEnabled = false
        payButton.isHidden = true
        payButton.isEnabled = false
        
        var payButtonText = NSLocalizedString("Controllers/CheckoutViewController/PayButtonText",
                                              value: "Pay",
                                              comment: "Text on pay button. This is followed by the amount to pay")
        
        if let cost = order.cost {
            payButtonText = payButtonText + " \(cost.total.formatted)"
        }
        payButton.setTitle(payButtonText, for: .normal)
        
        let paymentMethod = order.paymentMethod
        
        if paymentMethod == .applePay {
            applePayButton?.isHidden = false
            applePayButton?.isEnabled = true
        } else {
            payButton.isHidden = false
            payButton.isEnabled = true
            payButton.alpha = 1.0
            payButton.backgroundColor = payButtonOriginalColor
            
            var payButtonAccessibilityLabel = payButtonText
            var payButtonHint: String?
            
            let paymentMethodIsValid = self.paymentMethodIsValid()
            let deliveryDetailsAreValid = self.deliveryDetailsAreValid()
            if !paymentMethodIsValid || !deliveryDetailsAreValid {
                payButton.alpha = 0.5
                payButton.backgroundColor = UIColor.lightGray
                payButtonAccessibilityLabel += ". Disabled."
                
                if !paymentMethodIsValid && !deliveryDetailsAreValid {
                    payButtonHint = NSLocalizedString("Accessibility/AddPaymentMethodAndDeliveryDetailsHint", value: "Add a payment method and delivery details to place your order.", comment: "Accessibility hint letting the user know that they need to add a payment method and delivery details to be able to place the order.")
                } else if !paymentMethodIsValid {
                    payButtonHint = NSLocalizedString("Accessibility/AddPaymentMethodHint", value: "Add a payment method to place your order.", comment: "Accessibility hint letting the user know that they need to add a payment method to be able to place the order.")
                } else if !deliveryDetailsAreValid {
                    payButtonHint = NSLocalizedString("Accessibility/AddDeliveryDetailsHint", value: "Enter delivery details to place your order.", comment: "Accessibility hint letting the user know that they need to enter delivery details to be able to place the order.")
                }
            }
            payButton.accessibilityLabel = payButtonAccessibilityLabel
            payButton.accessibilityHint = payButtonHint
        }
    }
    
    private func indicatePaymentMethodError() {
        paymentMethodIconImageView.isHidden = true
        paymentMethodLabel.isHidden = false
        paymentMethodLabel.text = Constants.labelRequiredText
        paymentMethodLabel.textColor = Constants.detailsLabelColorRequired
        paymentMethodTitleLabel.text = Constants.paymentMethodText
        
        paymentMethodView.accessibilityValue = Constants.labelRequiredText
    }
    
    private func deliveryDetailsAreValid() -> Bool {
        return (!order.orderIsFree && order.paymentMethod == .applePay) || (order.deliveryDetails?.address?.isValid ?? false)
    }
    
    private func paymentMethodIsValid() -> Bool {
        return order.orderIsFree || (order.paymentMethod != nil && (order.paymentMethod != .creditCard || Card.currentCard != nil))
    }
    
    private func indicateDeliveryDetailsError() {
        deliveryDetailsLabel.text = Constants.labelRequiredText
        deliveryDetailsLabel.textColor = Constants.detailsLabelColorRequired
        
        deliveryDetailsView.accessibilityValue = Constants.labelRequiredText
    }
    
    private func checkRequiredInformation() -> Bool {
        let paymentMethodIsValid = self.paymentMethodIsValid()
        if !paymentMethodIsValid {
            indicatePaymentMethodError()
        }
        
        let deliveryDetailsAreValid = self.deliveryDetailsAreValid()
        if !deliveryDetailsAreValid {
            indicateDeliveryDetailsError()
        }
        
        return deliveryDetailsAreValid && paymentMethodIsValid
    }
    
    private func checkPromoCode() -> Bool {
        //promo code
        if let invalidReason = order.cost?.promoCodeInvalidReason {
            promoCodeTextField.attributedPlaceholder = NSAttributedString(string: invalidReason, attributes: [NSAttributedStringKey.foregroundColor: Constants.detailsLabelColorRequired])
            promoCodeTextField.text = nil
            promoCodeTextField.placeholder = invalidReason
            
            self.promoCodeClearButton.isHidden = true
            self.promoCodeAccessoryConstraint.priority = .defaultLow
            self.promoCodeNormalConstraint.priority = .defaultHigh
            
            return true
        }
        
        return false
    }
    
    private func handlePromoCodeChanges() {
        
        guard let text = promoCodeTextField.text else {
            return
        }
        
        //textfield is empty
        if text.isEmpty {
            if !promoCodeTextField.isFirstResponder {
                promoCodeClearButton.isHidden = true
                promoCodeAccessoryConstraint.priority = .defaultLow
                promoCodeNormalConstraint.priority = .defaultHigh
            }
            if order.promoCode != nil { //it wasn't empty before
                order.promoCode = nil
                refresh(showProgress: false)
            }
            return
        }
        
        //textfield is not empty
        if previousPromoText != text { //and it has changed
            order.promoCode = text
            promoCodeAccessoryConstraint.priority = .defaultHigh
            promoCodeNormalConstraint.priority = .defaultLow
            promoCodeActivityIndicator.startAnimating()
            promoCodeTextField.isUserInteractionEnabled = false
            promoCodeClearButton.isHidden = true
            refresh(showProgress: false)
        }
    }
    
    private func showReceipt() {
        order.lastSubmissionDate = Date()
        NotificationCenter.default.post(name: OrdersNotificationName.orderWasCreated, object: order)
        
        OrderManager.shared.saveBasketOrder()
        
        if self.presentedViewController == nil {
            self.performSegue(withIdentifier: Constants.receiptSegueName, sender: nil)
        }
        else {
            self.dismiss(animated: true, completion: {
                self.performSegue(withIdentifier: Constants.receiptSegueName, sender: nil)
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case Constants.receiptSegueName:
            if let receiptViewController = segue.destination as? ReceiptViewController {
                receiptViewController.order = order
                receiptViewController.dismissDelegate = dismissDelegate

            }
        case Constants.segueIdentifierPaymentMethods:
            if let paymentMethodsViewController = segue.destination as? PaymentMethodsViewController {
                paymentMethodsViewController.order = order
            }
        default:
            break
        }
    }
    
    //MARK: - Actions
    
    @IBAction func promoCodeDismissViewTapped(_ sender: Any) {
        promoCodeTextField.resignFirstResponder()
        promoCodeDismissGestureRecognizer.isEnabled = false
        
        handlePromoCodeChanges()
        promoCodeTextField.setNeedsLayout()
        promoCodeTextField.layoutIfNeeded()
    }
    
    @IBAction func promoCodeViewTapped(_ sender: Any) {
        promoCodeTextField.becomeFirstResponder()
    }
    
    @IBAction func promoCodeClearButtonTapped(_ sender: Any) {
        promoCodeTextField.text = ""
        handlePromoCodeChanges()
    }
    
    @IBAction private func presentAmountPicker(selectedAmount: Int) {
        let amountPickerViewController = photobookMainStoryboard.instantiateViewController(withIdentifier: "AmountPickerViewController") as! AmountPickerViewController
        amountPickerViewController.optionName = NSLocalizedString("Controllers/CheckoutViewController/ItemAmountPickerTitle",
                                                                              value: "Select amount",
                                                                              comment: "The title displayed on the picker view for the amount of basket items")
        amountPickerViewController.selectedValue = selectedAmount
        amountPickerViewController.minimum = 1
        amountPickerViewController.maximum = 10
        amountPickerViewController.delegate = self
        amountPickerViewController.modalPresentationStyle = .overCurrentContext
        self.present(amountPickerViewController, animated: false, completion: nil)
    }
    
    @IBAction func payButtonTapped(_ sender: UIButton) {
        guard checkRequiredInformation() else { return }
        
        guard let cost = order.cost else {
            progressOverlayViewController.show(message: Constants.loadingPaymentText)
            order.updateCost { [weak welf = self] (error: Error?) in
                guard error == nil else {
                    guard let stelf = welf else { return }
                    MessageBarViewController.show(message: ErrorMessage(error!), parentViewController: stelf, offsetTop: stelf.navigationController!.navigationBar.frame.maxY, centred: true) {
                        welf?.payButtonTapped(sender)
                    }
                    return
                }
                
                welf?.progressOverlayViewController.hide()
                welf?.payButtonTapped(sender)
            }
            return
        }
            
        if cost.total.value == 0.0 {
            // The user must have a promo code which reduces this order cost to nothing, lucky user :)
            order.paymentToken = nil
            showReceipt()
        }
        else {
            if order.paymentMethod == .applePay{
                modalPresentationDismissedGroup.enter()
            }
            
            guard let paymentMethod = order.paymentMethod else { return }
            
            progressOverlayViewController.show(message: Constants.loadingPaymentText)
            paymentManager.authorizePayment(cost: cost, method: paymentMethod)
        }
    }
    
    //MARK: Keyboard Notifications
    
    @objc func keyboardWillChangeFrame(notification: Notification) {
        let userInfo = notification.userInfo
        guard let size = (userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size else { return }
        let time = (userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.5
        
        guard promoCodeTextField.isFirstResponder else { return }
        
        optionsViewTopConstraint.constant =  -size.height - promoCodeViewHeightConstraint.constant
        
        self.optionsViewBottomContraint.priority = .defaultLow
        self.optionsViewTopConstraint.priority = .defaultHigh
        UIView.animate(withDuration: time) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(notification: Notification){
        guard promoCodeTextField.isFirstResponder else { return }
        let userInfo = notification.userInfo
        let time = (userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.5
        
        self.optionsViewBottomContraint.priority = .defaultHigh
        self.optionsViewTopConstraint.priority = .defaultLow
        UIView.animate(withDuration: time) {
            self.view.layoutIfNeeded()
        }
    }
}

extension CheckoutViewController: UITextFieldDelegate {
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        promoCodeDismissGestureRecognizer.isEnabled = true
        
        previousPromoText = textField.text
        promoCodeTextField.placeholder = Constants.promoCodePlaceholderText
        //display delete button
        promoCodeClearButton.isHidden = false
        promoCodeAccessoryConstraint.priority = .defaultHigh
        promoCodeNormalConstraint.priority = .defaultLow
        
        textField.setNeedsLayout()
        textField.layoutIfNeeded()
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        promoCodeDismissGestureRecognizer.isEnabled = false
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        handlePromoCodeChanges()
        textField.setNeedsLayout()
        textField.layoutIfNeeded()
        
        return false
    }
}

extension CheckoutViewController: AmountPickerDelegate {
    func amountPickerDidSelectValue(_ value: Int) {
        guard let index = editingProductIndex else { return }
        
        order.products[index].itemCount = value
        if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BasketProductTableViewCell {
            updateProductCell(cell, for: index)
        }
        refresh()
    }
}

extension CheckoutViewController: PaymentAuthorizationManagerDelegate {
    
    func costUpdated() {
        updateViews()
    }
    
    func modalPresentationWillBegin() {
        progressOverlayViewController.hide()
    }
    
    func paymentAuthorizationDidFinish(token: String?, error: Error?, completionHandler: ((PKPaymentAuthorizationStatus) -> Void)?) {
        if let error = error {
            progressOverlayViewController.hide()
            self.present(UIAlertController(errorMessage: ErrorMessage(error)), animated: true)
            return
        }
        
        order.paymentToken = token
        showReceipt()
    }
    
    func modalPresentationDidFinish() {
        order.updateCost { [weak welf = self] (error: Error?) in
            guard let stelf = welf else { return }
            
            stelf.modalPresentationDismissedGroup.leave()
            
            if let error = error {
                MessageBarViewController.show(message: ErrorMessage(error), parentViewController: stelf, offsetTop: stelf.navigationController!.navigationBar.frame.maxY, centred: true) {
                    welf?.modalPresentationDidFinish()
                }
                return
            }
        }
    }
    
}

extension CheckoutViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return order.products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BasketProductTableViewCell.reuseIdentifier, for: indexPath) as! BasketProductTableViewCell
        updateProductCell(cell, for: indexPath.row)
        cell.delegate = self
        return cell
    }
}

extension CheckoutViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            order.products.remove(at: indexPath.row)
            OrderManager.shared.saveBasketOrder()
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            guard !order.products.isEmpty else {
                if isPresentedModally {
                    tappedCancel()
                } else {
                    navigationController?.popViewController(animated: true)
                }
                return
            }
            refresh(forceCostUpdate: true, forceShippingMethodsUpdate: false)
        }
    }
}

extension CheckoutViewController: BasketProductTableViewCellDelegate {
    func didTapAmountButton(for productIdentifier: String) {
        editingProductIndex = order.products.index(where: { $0.identifier == productIdentifier })
        let selectedAmount = editingProductIndex != nil ? order.products[editingProductIndex!].itemCount : 1
        presentAmountPicker(selectedAmount: selectedAmount)
    }
    
    
}
