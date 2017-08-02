//
//  MediaBrowser.swift
//  MediaBrowser-Sample
//
//  Created by Joe on 2017/1/9.
//  Copyright © 2017年 Joe. All rights reserved.
//

import UIKit
import AVFoundation

public class MediaItem: NSObject {
    var image: UIImage?
    var imageUrl: URL?
    
    func loadImage(completeHandler: @escaping ((UIImage?)->())){
        if let url = imageUrl, image == nil{
            let request = URLRequest(url: url)
            let task = URLSession.shared.dataTask(with: request) { (data, _, err) in
                if err != nil{
                    print(err.debugDescription)
                }else if let data = data{
                    DispatchQueue.main.async {
                        let image = UIImage(data: data)
                        self.image = image
                        completeHandler(image)
                    }
                }
            }
            task.resume()
        }else{
            completeHandler(image)
        }
    }
}

public class ImageItem: MediaItem {
    
    public convenience init(image: UIImage){
        self.init()
        self.image = image
    }
    
    public convenience init(url: URL){
        self.init()
        self.imageUrl = url
    }

}

public class VideoItem: MediaItem {
    
    private(set) var item: AVPlayerItem?
    
    public convenience init(image: UIImage, videoUrl: URL){
        self.init()
        self.image = image
        self.item = AVPlayerItem(url: videoUrl)
    }
    
    public convenience init(url: URL, videoUrl: URL){
        self.init()
        self.imageUrl = url
        self.item = AVPlayerItem(url: videoUrl)
    }
}

class MediaItemView: UIView {
    
    var mediaItem: MediaItem?{
        didSet{
            if mediaItem is VideoItem && playerView == nil{
                playerView = UIView()
                playerView!.frame = bounds
                playerView!.alpha = 0
                addSubview(playerView!)
                
                playerLayer = AVPlayerLayer()
                playerLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
                playerView!.layer.addSublayer(playerLayer!)
            }
            
            completedPreload = false
            if player != nil && player.rate == 1{
                stop()
            }
        }
    }
    
    var player: AVPlayer!{
        didSet{
            playerLayer?.player = player
        }
    }
    
    private(set) var completedPreload = false
    
    private let imageView = UIImageView()
    private var playerView: UIView?
    private var playerLayer: AVPlayerLayer?
    private var loadingView = LoadingView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews(){
        super.layoutSubviews()
        playerView?.frame = bounds
        playerLayer?.frame = bounds
    }
    
    private func setupView(){
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let hImageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[imageView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["imageView": imageView])
        let vImageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[imageView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["imageView": imageView])
        addConstraints(hImageViewConstraints)
        addConstraints(vImageViewConstraints)
        
        addSubview(loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        let wLoadingViewConstraint = NSLayoutConstraint(item: loadingView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30)
        let hLoadingViewConstraint = NSLayoutConstraint(item: loadingView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30)
        let cxLoadingViewConstraint = NSLayoutConstraint(item: loadingView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0)
        let cyLoadingViewConstraint = NSLayoutConstraint(item: loadingView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0)
        addConstraint(wLoadingViewConstraint)
        addConstraint(hLoadingViewConstraint)
        addConstraint(cxLoadingViewConstraint)
        addConstraint(cyLoadingViewConstraint)
        
        loadingView.start()
    }
    
    func preload(){
        mediaItem?.loadImage(completeHandler: { (image) in
            self.loadingView.end()
            self.imageView.image = image
            self.completedPreload = true
        })
    }
    
    func load(){
        if let videoItem = mediaItem as? VideoItem{
            player?.replaceCurrentItem(with: videoItem.item)
            if completedPreload{
                UIView.animate(withDuration: 0.5, delay: 2, options: .layoutSubviews, animations: {
                    self.playerView?.alpha = 1
                    self.player?.play()
                }, completion: nil)
            }else{
                let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(self.loadTimerHandler(_:)), userInfo: nil, repeats: true)
                RunLoop.current.add(timer, forMode: .defaultRunLoopMode)
            }
        }
    }
    
    func loadTimerHandler(_ timer: Timer){
        if self.completedPreload{
            timer.invalidate()
            if self.player!.status == .readyToPlay{
                UIView.animate(withDuration: 0.5, delay: 2, options: .layoutSubviews, animations: {
                    self.playerView?.alpha = 1
                    self.player?.play()
                }, completion: nil)
            }
        }
    }
    
    func restore(){
        player?.pause()
        self.playerView?.alpha = 0
    }
    
    func stop(){
        restore()
        player.seek(to: kCMTimeZero)
    }
    
}

public class MediaBrowser: UIView, UIScrollViewDelegate {
    
    public var mediaItems: [MediaItem] = []{
        didSet{
            setupItemView()
        }
    }
    
    public var showPage = true
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let pageView = UIView()
    private let pageLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    private let player = AVPlayer()
    private var mediaItemViews: [MediaItemView] = []
    
    public private(set) var currentPage: Int = 0{
        didSet{
            pageLabel.text = "\(currentPage + 1)/\(mediaItems.count)"
        }
    }
    
    private var completedPageAnimation = true
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = pageView.bounds
    }
    
    private func setup(){
        setupScrollView()
        setupContentView()
        setupPageView()
    }
    
    private func setupScrollView(){
        scrollView.frame = bounds
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.isPagingEnabled = true
        scrollView.maximumZoomScale = 2
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        self.addSubview(scrollView)
        
        let hScrollViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[scrollView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["scrollView":scrollView])
        let vScrollViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[scrollView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["scrollView":scrollView])
        self.addConstraints(hScrollViewConstraints)
        self.addConstraints(vScrollViewConstraints)
    }
    
    private func setupContentView(){
        contentView.frame = bounds
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let hContentViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["contentView": contentView])
        let vContentViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["contentView": contentView])
        let widthEqualConstraint = NSLayoutConstraint(item: scrollView, attribute: .width, relatedBy: .equal, toItem: contentView, attribute: .width, multiplier: 1, constant: 0)
        widthEqualConstraint.priority = UILayoutPriorityDefaultHigh
        let heightEqualConstraint = NSLayoutConstraint(item: scrollView, attribute: .height, relatedBy: .equal, toItem: contentView, attribute: .height, multiplier: 1, constant: 0)
        heightEqualConstraint.priority = UILayoutPriorityDefaultHigh
        self.addConstraint(widthEqualConstraint)
        self.addConstraint(heightEqualConstraint)
        scrollView.addConstraints(hContentViewConstraints)
        scrollView.addConstraints(vContentViewConstraints)
    }
    
    private func setupPageView(){
        pageView.translatesAutoresizingMaskIntoConstraints = false
        pageView.alpha = 0
        self.addSubview(pageView)
        let hPageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[pageView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["pageView": pageView])
        let vPageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[pageView(50)]|", options: .directionLeadingToTrailing, metrics: nil, views: ["pageView": pageView])
        self.addConstraints(hPageViewConstraints)
        self.addConstraints(vPageViewConstraints)
        let blackColor = UIColor.black.withAlphaComponent(0.5)
        let transparentColor = UIColor.clear
        
        pageView.layoutIfNeeded()
        gradientLayer.colors = [transparentColor.cgColor, blackColor.cgColor]
        pageView.layer.insertSublayer(gradientLayer, at: 0)
        
        
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.textColor = UIColor.white
        pageLabel.textAlignment = .center
        pageLabel.font = UIFont.boldSystemFont(ofSize: 20)
        pageView.addSubview(pageLabel)
        
        let hPageLabelConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[pageLabel]|", options: .directionLeadingToTrailing, metrics: nil, views: ["pageLabel": pageLabel])
        let vPageLabelconstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[pageLabel(50)]|", options: .directionLeadingToTrailing, metrics: nil, views: ["pageLabel": pageLabel])
        pageView.addConstraints(hPageLabelConstraints)
        pageView.addConstraints(vPageLabelconstraints)
    }
    
    private func setupItemView(){
        mediaItemViews = []
        for view in contentView.subviews{
            view.removeFromSuperview()
        }
        
        if mediaItems.count == 0{
            return
        }
        
        var hConstraintsViews: [String: AnyObject] = ["scrollView": scrollView]
        var hConstraintsFormat = "H:|"
        var index = 0
        for item in mediaItems{
            let mediaItemView = MediaItemView(frame: bounds)
            mediaItemView.mediaItem = item
            mediaItemView.player = player
            mediaItemView.translatesAutoresizingMaskIntoConstraints = false
            mediaItemViews.append(mediaItemView)
            contentView.addSubview(mediaItemView)
            
            let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view(==scrollView)]|", options: .directionLeadingToTrailing, metrics: nil, views: ["scrollView": scrollView, "view": mediaItemView])
            self.addConstraints(vConstraints)
            
            let viewName = "view\(index)"
            hConstraintsViews[viewName] = mediaItemView
            hConstraintsFormat += "[\(viewName)(==scrollView)]"
            
            index += 1
        }
        hConstraintsFormat += "|"
        
        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: hConstraintsFormat, options: .directionLeadingToTrailing, metrics: nil, views: hConstraintsViews)
        self.addConstraints(hConstraints)
        
        currentPage = 0
        checkPage()
    }
    
//    public func addMediaItems(_ items: [MediaItem]){
//        
//    }
//    
//    public func addMediaItem(_ item: MediaItem){
//        addMediaItems([item])
//    }
    
    private func checkPage(){
        if mediaItemViews[currentPage].completedPreload == false{
            mediaItemViews[currentPage].preload()
        }
        mediaItemViews[currentPage].load()
        
        if currentPage - 1 >= 0{
            mediaItemViews[currentPage - 1].preload()
        }
        if currentPage + 1 < mediaItemViews.count{
            mediaItemViews[currentPage + 1].preload()
        }
    }
    
    private func showPageNumbers(){
        if completedPageAnimation == false{
            self.pageView.alpha = 1
        }
        UIView.animate(withDuration: 0.3) {
            self.pageView.alpha = 1
        }
    }
    
    private func hidePageNumbers(){
        completedPageAnimation = false
        UIView.animate(withDuration: 0.3, delay: 1, options: .layoutSubviews, animations: { 
            self.pageView.alpha = 0
        }) { (_) in
            self.completedPageAnimation = true
        }
    }
    
    public func setPage(_ page: Int, animated: Bool){
        scrollView.setContentOffset(CGPoint(x: CGFloat(page) * scrollView.bounds.width, y: 0),
                                    animated: animated)
        if mediaItemViews.count > 0 && scrollView.zoomScale == 1{
            mediaItemViews[currentPage].stop()
            if showPage{
                showPageNumbers()
            }
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.zoomScale == 1{
            let newPage = lroundf(Float(scrollView.contentOffset.x / scrollView.frame.width))
            if currentPage != newPage && newPage >= 0 && newPage < mediaItemViews.count{
                currentPage = newPage
            }
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if mediaItemViews.count > 0 && scrollView.zoomScale == 1{
            mediaItemViews[currentPage].stop()
            if showPage{
                showPageNumbers()
            }
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if mediaItemViews.count > 0 && scrollView.zoomScale == 1{
            checkPage()
            if showPage{
                hidePageNumbers()
            }
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if mediaItemViews.count > 0{
            checkPage()
            if showPage{
                hidePageNumbers()
            }
        }
    }
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale != 1{
            scrollView.isPagingEnabled = false
            scrollView.contentSize = CGSize(width: frame.size.width * scrollView.zoomScale * CGFloat(currentPage + 1), height: frame.size.height * scrollView.zoomScale)
            scrollView.contentInset = UIEdgeInsetsMake(0, -frame.size.width *  scrollView.zoomScale * CGFloat(currentPage), 0, 0)
            
            mediaItemViews[currentPage].stop()
            
            if currentPage - 1 >= 0{
                mediaItemViews[currentPage - 1].isHidden = true
            }
            if currentPage + 1 < mediaItemViews.count{
                mediaItemViews[currentPage + 1].isHidden = true
            }
        }else{
            scrollView.isPagingEnabled = true
            scrollView.contentInset = UIEdgeInsets.zero
            
            mediaItemViews[currentPage].load()
            
            if currentPage - 1 >= 0{
                mediaItemViews[currentPage - 1].isHidden = false
            }
            if currentPage + 1 < mediaItemViews.count{
                mediaItemViews[currentPage + 1].isHidden = false
            }
        }
    }
}

class LoadingView: UIImageView{
    
    private(set) var isFinished: Bool = true
    
    init(){
        super.init(frame: CGRect.zero)
        image = UIImage(named: "loading_icon")
        isHidden = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        image = UIImage(named: "loading_icon")
        isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        image = UIImage(named: "loading_icon")
        isHidden = true
    }
    
    func start() {
        isFinished = false
        if let _ = self.layer.animation(forKey: "rotation"){
            
        }else{
            let animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.toValue = Double.pi * 2
            animation.duration = 0.5
            animation.isCumulative = true
            animation.repeatCount = Float(CGFloat.greatestFiniteMagnitude)
            self.layer.add(animation, forKey: "rotation")
        }
        
        self.isHidden = false
    }
    
    func end() {
        isFinished = true
        self.layer.removeAnimation(forKey: "rotation")
        self.isHidden = true
    }
}





