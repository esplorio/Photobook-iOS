//
//  TutorialViewController.swift
//  Photobook
//
//  Created by Jaime Landazuri on 23/10/2018.
//  Copyright © 2018 Kite.ly. All rights reserved.
//

import UIKit

class TutorialViewController: UIViewController {

    private struct Constants {
        static let tutorialPageViewControllerIdentifier = "TutorialPageViewController"
        static let pageViewControllerEmbedSegueIdentifier = "pageViewControllerEmbedSegue"
    }
    
    private var tutorialPages = [
        ["image": "onboarding1",
         "text": NSLocalizedString("Tutorial/Screen1", value: "<b>Add a title</b> to your book by tapping on the spine", comment: "Explains how to edit the spine text")],
        ["image": "onboarding2",
         "text": NSLocalizedString("Tutorial/Screen1", value: "Swipe to <b>duplicate, add or delete</b> pages", comment: "Explains how to edit pages")],
        ["image": "onboarding3",
         "text": NSLocalizedString("Tutorial/Screen1", value: "<b>Press and hold</b> to move pages", comment: "Explains how to move pages")]
    ]
    
    private lazy var tutorialPageControllers: [TutorialPageViewController] = {
        var pageControllers = [TutorialPageViewController]()
        for page in tutorialPages {
            let pageController = photobookMainStoryboard.instantiateViewController(withIdentifier: Constants.tutorialPageViewControllerIdentifier) as! TutorialPageViewController
            pageController.image = UIImage(namedInPhotobookBundle: page["image"]!)
            pageController.text = page["text"]
            pageControllers.append(pageController)
        }
        return pageControllers
    }()
    
    private weak var pageViewController: UIPageViewController!
    
    @IBOutlet private weak var skipButton: UIButton!
    @IBOutlet private weak var previousButton: UIButton!
    @IBOutlet private weak var nextButton: UIButton!
    @IBOutlet private weak var pageControl: UIPageControl!
    
    weak var delegate: DismissDelegate?
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == Constants.pageViewControllerEmbedSegueIdentifier else { return }
        
        pageViewController = segue.destination as? UIPageViewController
        pageViewController.dataSource = self
        pageViewController.delegate = self
        let firstPageViewController = tutorialPageControllers.first!
        pageViewController.setViewControllers([firstPageViewController], direction: .forward, animated: false, completion: nil)
        
        previousButton.alpha = 0.0
    }
    
    // MARK: - Button Actions
    
    @IBAction func tappedSkipButton(_ sender: UIButton) {
        delegate?.wantsToDismiss?(self)
    }
    
    @IBAction func tappedPreviousButton(_ sender: UIButton) {
        guard pageControl.currentPage > 0 else { return }
        let previousPageViewController = tutorialPageControllers[pageControl.currentPage - 1]
        pageViewController.setViewControllers([previousPageViewController], direction: .reverse, animated: true, completion: nil)
        pageViewControllerDidFinishAnimating()
    }
    
    @IBAction func tappedNextButton(_ sender: UIButton) {
        guard pageControl.currentPage < tutorialPages.count - 1 else {
            delegate?.wantsToDismiss?(self)
            return
        }
        let nextPageViewController = tutorialPageControllers[pageControl.currentPage + 1]
        pageViewController.setViewControllers([nextPageViewController], direction: .forward, animated: true, completion: nil)
        pageViewControllerDidFinishAnimating()
    }
    
    private func pageViewControllerDidFinishAnimating() {
        guard let pageViewController = pageViewController.viewControllers?.first as? TutorialPageViewController,
            let index = tutorialPageControllers.index(of: pageViewController)
            else {
                pageControl.currentPage = 0
                return
        }
        pageControl.currentPage = index
        
        // Update buttons
        UIView.animate(withDuration: 0.2) {
            let nextButtonTitle = index == self.tutorialPages.count - 1 ? CommonLocalizedStrings.done : CommonLocalizedStrings.next
            self.nextButton.setTitle(nextButtonTitle, for: .normal)
            self.previousButton.alpha = index == 0 ? 0.0 : 1.0
            self.skipButton.alpha = index < self.tutorialPages.count - 1 ? 1.0 : 0.0
        }
    }
}

extension TutorialViewController: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed else { return }
        pageViewControllerDidFinishAnimating()
    }
}

extension TutorialViewController: UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let pageViewController = viewController as? TutorialPageViewController,
            let index = tutorialPageControllers.index(of: pageViewController)
        else { return nil}
        
        if index == 0 { return nil }
        return tutorialPageControllers[index - 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let pageViewController = viewController as? TutorialPageViewController,
            let index = tutorialPageControllers.index(of: pageViewController)
            else { return nil}

        if index == tutorialPages.count - 1 { return nil }
        return tutorialPageControllers[index + 1]
    }
}
