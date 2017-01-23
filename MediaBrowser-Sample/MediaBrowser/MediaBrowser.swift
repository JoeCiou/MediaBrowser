//
//  MediaBrowser.swift
//  MediaBrowser-Sample
//
//  Created by Joe on 2017/1/9.
//  Copyright © 2017年 Joe. All rights reserved.
//

import UIKit
import AVFoundation

class MediaItem: NSObject {
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

class ImageItem: MediaItem {
    
    convenience init(image: UIImage){
        self.init()
        self.image = image
    }
    
    convenience init(url: URL){
        self.init()
        self.imageUrl = url
    }

}

class VideoItem: MediaItem {
    
    var item: AVPlayerItem?
    
    convenience init(image: UIImage, videoUrl: URL){
        self.init()
        self.image = image
        self.item = AVPlayerItem(url: videoUrl)
    }
    
    convenience init(url: URL, videoUrl: URL){
        self.init()
        self.imageUrl = url
        self.item = AVPlayerItem(url: videoUrl)
    }
}

class MediaItemView: UIView {
    
    var mediaItem: MediaItem?{
        didSet{
            setupView()
        }
    }
    var player: AVPlayer?{
        didSet{
            playerLayer = AVPlayerLayer(player: player!)
            playerLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            playerView.layer.addSublayer(playerLayer!)
        }
    }
    var isCompletePreload = false
    let contentView = UIView()
    private let imageView = UIImageView()
    private let playerView = UIView()
    private var playerLayer: AVPlayerLayer?
    private var loadingView = LoadingView()
    
    override func layoutSubviews(){
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    func setupView(){
        self.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        let hContentViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[contentView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["contentView": contentView])
        let vContentViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[contentView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["contentView": contentView])
        self.addConstraints(hContentViewConstraints)
        self.addConstraints(vContentViewConstraints)
        
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let hImageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[imageView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["imageView": imageView])
        let vImageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[imageView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["imageView": imageView])
        contentView.addConstraints(hImageViewConstraints)
        contentView.addConstraints(vImageViewConstraints)
        
        contentView.addSubview(loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        let wLoadingViewConstraint = NSLayoutConstraint(item: loadingView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30)
        let hLoadingViewConstraint = NSLayoutConstraint(item: loadingView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30)
        let cxLoadingViewConstraint = NSLayoutConstraint(item: loadingView, attribute: .centerX, relatedBy: .equal, toItem: contentView, attribute: .centerX, multiplier: 1, constant: 0)
        let cyLoadingViewConstraint = NSLayoutConstraint(item: loadingView, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1, constant: 0)
        contentView.addConstraint(wLoadingViewConstraint)
        contentView.addConstraint(hLoadingViewConstraint)
        contentView.addConstraint(cxLoadingViewConstraint)
        contentView.addConstraint(cyLoadingViewConstraint)
        
        loadingView.start()
        
        if mediaItem is VideoItem{
            playerView.frame = bounds
            contentView.addSubview(playerView)
            playerView.alpha = 0
        }
    }
    
    func preload(){
        mediaItem?.loadImage(completeHandler: { (image) in
            self.loadingView.end()
            self.imageView.image = image
            self.isCompletePreload = true
        })
    }
    
    func load(){
        if let videoItem = mediaItem as? VideoItem{
            player?.replaceCurrentItem(with: videoItem.item)
            if isCompletePreload{
                UIView.animate(withDuration: 0.5, delay: 2, options: .layoutSubviews, animations: {
                    self.playerView.alpha = 1
                    self.player?.play()
                }, completion: nil)
            }else{
                let timer = Timer(timeInterval: 0.1, repeats: true, block: { (timer) in
                    if self.isCompletePreload{
                        timer.invalidate()
                        if self.player!.status == .readyToPlay{
                            UIView.animate(withDuration: 0.5, delay: 2, options: .layoutSubviews, animations: {
                                self.playerView.alpha = 1
                                self.player?.play()
                            }, completion: nil)
                        }
                    }
                })
                RunLoop.current.add(timer, forMode: .defaultRunLoopMode)
            }
        }
    }
    
    func restore(){
        player?.pause()
        self.playerView.alpha = 0
    }
    
}

class MediaBrowser: UIView, UIScrollViewDelegate {
    
    var mediaItems: [MediaItem] = []{
        didSet{
            setupItemView()
        }
    }
    var showPage = true
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let pageView = UIView()
    private let pageLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    private let player = AVPlayer()
    private var mediaItemViews: [MediaItemView] = []
    private var page: Int = 0{
        didSet{
            pageLabel.text = "\(page+1)/\(mediaItems.count)"
        }
    }
    private var isCompleteAnimationWithShowPage = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = pageView.bounds
    }
    
    func setupView(){
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
    
    func setupItemView(){
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
        print(hConstraintsFormat)
        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: hConstraintsFormat, options: .directionLeadingToTrailing, metrics: nil, views: hConstraintsViews)
        self.addConstraints(hConstraints)
        
        page = 0
        checkPage()
    }
    
    func checkPage(){
        if mediaItemViews[page].isCompletePreload == false{
            mediaItemViews[page].preload()
        }
        mediaItemViews[page].load()
        
        if page - 1 >= 0{
            mediaItemViews[page - 1].preload()
        }
        if page + 1 < mediaItemViews.count{
            mediaItemViews[page + 1].preload()
        }
    }
    
    func showPageNumbers(){
        if isCompleteAnimationWithShowPage == false{
            self.pageView.alpha = 1
        }
        UIView.animate(withDuration: 0.3) {
            self.pageView.alpha = 1
        }
    }
    
    func hidePageNumbers(){
        isCompleteAnimationWithShowPage = false
        UIView.animate(withDuration: 0.3, delay: 1, options: .layoutSubviews, animations: { 
            self.pageView.alpha = 0
        }) { (_) in
            self.isCompleteAnimationWithShowPage = true
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.zoomScale == 1{
            let newPage = lroundf(Float(scrollView.contentOffset.x / scrollView.frame.width))
            if page != newPage && newPage >= 0 && newPage < mediaItemViews.count{
                page = newPage
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if mediaItemViews.count > 0 && scrollView.zoomScale == 1{
            mediaItemViews[page].restore()
            if showPage{
                showPageNumbers()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if mediaItemViews.count > 0{
            checkPage()
            if showPage{
                hidePageNumbers()
            }
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale != 1{
            scrollView.isPagingEnabled = false
            scrollView.contentSize = CGSize(width: frame.size.width * scrollView.zoomScale * CGFloat(page + 1), height: frame.size.height * scrollView.zoomScale)
            scrollView.contentInset = UIEdgeInsetsMake(0, -frame.size.width *  scrollView.zoomScale * CGFloat(page), 0, 0)
        }else{
            scrollView.isPagingEnabled = true
            scrollView.contentInset = UIEdgeInsets.zero
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
            animation.toValue = M_PI*2
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





