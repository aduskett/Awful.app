//  ThreadPeekPopController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import MRProgress
import UIKit

final class ThreadPeekPopController: NSObject, PreviewActionItemProvider, UIViewControllerPreviewingDelegate {
    private weak var previewingViewController: UIViewController?
    private var thread: AwfulThread?
    
    init<ViewController: UIViewController>(previewingViewController: ViewController) where ViewController: ThreadPeekPopControllerDelegate {
        self.previewingViewController = previewingViewController
        
        super.init()
        
        previewingViewController.registerForPreviewing(with: self, sourceView: previewingViewController.view)
    }
    
    // MARK: PreviewActionItemProvider
    
    var previewActionItems: [UIPreviewActionItem] {
        let copyAction = UIPreviewAction(title: "Copy URL", style: .default) { action, previewViewController in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            
            let components = NSURLComponents(string: "https://forums.somethingawful.com/showthread.php")!
            var queryItems: [NSURLQueryItem] = []
            queryItems.append(NSURLQueryItem(name: "threadid", value: thread.threadID))
            queryItems.append(NSURLQueryItem(name: "perpage", value: "40"))
            if (postsViewController.page > 1) {
                queryItems.append(NSURLQueryItem(name:"pagenumber", value: "\(postsViewController.page)"))
            }
            components.queryItems = queryItems as [URLQueryItem]
            
            let URL = components.url!
            AwfulSettings.shared().lastOfferedPasteboardURL = URL.absoluteString
            UIPasteboard.general.awful_URL = URL as NSURL?
        }
        
        let markAsReadAction = UIPreviewAction(title: "Mark Thread As Read", style: .default) { action, previewViewController in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            
            AwfulForumsClient.shared().listPosts(in: thread, writtenBy: nil, onPage: AwfulThreadPage.last.rawValue, updateLastReadPost: true, andThen: { (error: Error?, _, _, _) -> Void in
                guard let
                    error = error,
                    let previewingViewController = postsViewController.parent
                else {
                    return
                }
                
                let alert = UIAlertController(networkError: error as NSError, handler: nil)
                previewingViewController.present(alert, animated: true, completion: nil)
            })
        }
        
        let bookmarkTitle = thread?.bookmarked == true ? "Remove Bookmark" : "Add Bookmark"
        let bookmarkStyle: UIPreviewActionStyle = thread?.bookmarked == true ? .destructive : .default
        let bookmarkAction = UIPreviewAction(title: bookmarkTitle, style: bookmarkStyle) { action, previewViewController in
            guard let postsViewController = previewViewController as? PostsPageViewController else {
                return
            }
            let thread = postsViewController.thread
            
            AwfulForumsClient.shared().setThread(thread, isBookmarked:!thread.bookmarked) { (error: Error?) in
                guard let presentingViewController = previewViewController.parent else {
                    return
                }
                
                if let error = error {
                    let alert = UIAlertController(networkError: error, handler: nil)
                    presentingViewController.presentViewController(alert, animated: true, completion: nil)
                } else {
                    let title = thread.bookmarked ? "Added Bookmark" : "Removed Bookmark"
                    let overlay = MRProgressOverlayView.showOverlayAddedTo(presentingViewController.view, title: title, mode: .Checkmark, animated: true)
                    
                    NSTimer.scheduledTimerWithInterval(0.7) { timer in
                        overlay.dismiss(true)
                    }
                }
            }
        }
        
        return [copyAction, markAsReadAction, bookmarkAction]
    }
    
    // MARK: UIViewControllerPreviewingDelegate
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let
            delegate = previewingViewController as? ThreadPeekPopControllerDelegate,
            let thread = delegate.threadForLocation(location: location)
        else {
            return nil
        }
        
        self.thread = thread
        
        let postsViewController = PostsPageViewController(thread: thread)
        postsViewController.restorationIdentifier = "Posts"
        // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
        let targetPage = thread.beenSeen ? AwfulThreadPage.nextUnread.rawValue : 1
        postsViewController.loadPage(rawPage: targetPage, updatingCache: true, updatingLastReadPost: false)
        
        postsViewController.preferredContentSize = CGSize(width: 0, height: 500)
        postsViewController.previewActionItemProvider = self
        
        if let view = delegate.viewForThread(thread: thread) {
            previewingContext.sourceRect = view.frame
        }
        
        return postsViewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        guard let viewController = previewingViewController else {
            return
        }
        
        if let postsViewController = viewControllerToCommit as? PostsPageViewController {
            postsViewController.loadPage(rawPage: postsViewController.page, updatingCache: true, updatingLastReadPost: true)
        }
        
        viewController.show(viewControllerToCommit, sender: self)
    }
}

protocol ThreadPeekPopControllerDelegate {
    func threadForLocation(location: CGPoint) -> AwfulThread?
    func viewForThread(thread: AwfulThread) -> UIView?
}

@objc protocol PreviewActionItemProvider {
    var previewActionItems: [UIPreviewActionItem] { get }
}
