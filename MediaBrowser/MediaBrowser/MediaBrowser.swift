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
    
    func loadImage(completeHandler: ((UIImage?)->())? = nil){
        if let url = imageUrl, image == nil{
            let request = URLRequest(url: url)
            let task = URLSession.shared.dataTask(with: request) { (data, _, err) in
                if err != nil{
                    print(err.debugDescription)
                }else if let data = data{
                    DispatchQueue.main.async {
                        let image = UIImage(data: data)
                        self.image = image
                        completeHandler?(image)
                    }
                }
            }
            task.resume()
        }else{
            completeHandler?(image)
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

class MediaItemView: UIView, UIScrollViewDelegate {
    
    var mediaItem: MediaItem?
    
    var player: AVPlayer!{
        didSet{
            playerLayer.player = player
        }
    }
    
    var isDisplaying: Bool = false
    
    private(set) var completedPreload = false
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let imageView = UIImageView()
    private var playerView = UIView()
    private var playerLayer = AVPlayerLayer()
    private var loadingView = LoadingView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews(){
        super.layoutSubviews()
        playerView.frame = bounds
        playerLayer.frame = bounds
    }
    
    private func setupScrollView(){
        scrollView.frame = bounds
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.maximumZoomScale = 2
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        addSubview(scrollView)
        
        let hScrollViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[scrollView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["scrollView":scrollView])
        let vScrollViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[scrollView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["scrollView":scrollView])
        addConstraints(hScrollViewConstraints)
        addConstraints(vScrollViewConstraints)
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
    
    private func setupImageView(){
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let hImageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[imageView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["imageView": imageView])
        let vImageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[imageView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["imageView": imageView])
        contentView.addConstraints(hImageViewConstraints)
        contentView.addConstraints(vImageViewConstraints)
    }
    
    private func setupLoadingView(){
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
    }
    
    private func setupPlayerView(){
        playerView.frame = bounds
        playerView.alpha = 0
        contentView.addSubview(playerView)
        
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        playerView.layer.addSublayer(playerLayer)
    }
    
    private func setup(){
        setupScrollView()
        setupContentView()
        setupImageView()
        setupLoadingView()
        setupPlayerView()
    }
    
    func resetScrollViewZoom(){
        scrollView.setZoomScale(1, animated: false)
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
                    self.playerView.alpha = 1
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
                    self.playerView.alpha = 1
                    self.player?.play()
                }, completion: nil)
            }
        }
    }
    
    func restore(){
        player?.pause()
        playerView.alpha = 0
    }
    
    func stop(){
        restore()
        player.seek(to: kCMTimeZero)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale != 1{
            stop()
        }else if isDisplaying{
            load()
        }
    }
    
}

class MediaItemCell: UICollectionViewCell{
    
    let mediaItemView: MediaItemView
    
    override init(frame: CGRect) {
        mediaItemView = MediaItemView(frame: frame)
        mediaItemView.translatesAutoresizingMaskIntoConstraints = false
        
        super.init(frame: frame)
        
        contentView.addSubview(mediaItemView)
        
        let hConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[mediaItemView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["mediaItemView": mediaItemView])
        let vConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[mediaItemView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["mediaItemView": mediaItemView])
        self.addConstraints(hConstraints)
        self.addConstraints(vConstraints)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class MediaBrowser: UIView {
    
    public var mediaItems: [MediaItem] = []{
        didSet{
            collectionView.reloadData()
            pageLabel.text = "\(currentPage + 1)/\(mediaItems.count)"
        }
    }
    
    public var delegate: MediaBrowserDelegate?
    public var isDisplayPageNumberEnabled = true
    
    fileprivate var collectionView: UICollectionView!
    fileprivate let pageView = UIView()
    fileprivate let pageLabel = UILabel()
    fileprivate let gradientLayer = CAGradientLayer()
    fileprivate let player = AVPlayer()
    
    public fileprivate(set) var currentPage: Int = 0{
        didSet{
            delegate?.mediaBrowser?(self, willMoving: currentPage)
            pageLabel.text = "\(currentPage + 1)/\(mediaItems.count)"
        }
    }
    
    fileprivate var completedPageAnimation = true
    
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
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize = bounds.size
        gradientLayer.frame = pageView.bounds
    }
    
    private func setup(){
        setupCollectionView()
        setupPageView()
    }
    
    private func setupCollectionView(){
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = bounds.size
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        collectionView = UICollectionView(frame: bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        addSubview(collectionView)
        
        let hCollectionViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[collectionView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["collectionView": collectionView])
        let vCollectionViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[collectionView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["collectionView": collectionView])
        addConstraints(hCollectionViewConstraints)
        addConstraints(vCollectionViewConstraints)
        
        collectionView.register(MediaItemCell.self, forCellWithReuseIdentifier: "MediaItemCell")
        
    }
    
    private func setupPageView(){
        pageView.translatesAutoresizingMaskIntoConstraints = false
        pageView.alpha = 0
        addSubview(pageView)
        let hPageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[pageView]|", options: .directionLeadingToTrailing, metrics: nil, views: ["pageView": pageView])
        let vPageViewConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:[pageView(50)]|", options: .directionLeadingToTrailing, metrics: nil, views: ["pageView": pageView])
        addConstraints(hPageViewConstraints)
        addConstraints(vPageViewConstraints)
        
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
    
    fileprivate func checkPage(){
        
        if let cell = collectionView.cellForItem(at: IndexPath(item: currentPage, section: 0)) as? MediaItemCell{
            cell.mediaItemView.load()
        }
        
        if currentPage - 1 >= 0{
            mediaItems[currentPage - 1].loadImage()
        }
        if currentPage + 1 < mediaItems.count{
            mediaItems[currentPage + 1].loadImage()
        }
    }
    
    fileprivate func showPageNumbers(){
        if completedPageAnimation == false{
            self.pageView.alpha = 1
        }
        UIView.animate(withDuration: 0.3) {
            self.pageView.alpha = 1
        }
    }
    
    fileprivate func hidePageNumbers(){
        completedPageAnimation = false
        UIView.animate(withDuration: 0.3, delay: 1, options: .layoutSubviews, animations: { 
            self.pageView.alpha = 0
        }) { (_) in
            self.completedPageAnimation = true
        }
    }
    
    public func setPage(_ page: Int, animated: Bool){
        collectionView.setContentOffset(CGPoint(x: CGFloat(page) * collectionView.bounds.width, y: 0),
                                    animated: animated)
        if mediaItems.count > 0{
            let cell = collectionView.cellForItem(at: IndexPath(item: currentPage, section: 0)) as! MediaItemCell
            cell.mediaItemView.stop()
            if isDisplayPageNumberEnabled{
                showPageNumbers()
            }
        }
    }
}

extension MediaBrowser: UICollectionViewDelegate, UICollectionViewDataSource{
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mediaItems.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaItemCell", for: indexPath) as! MediaItemCell
        cell.mediaItemView.mediaItem = mediaItems[indexPath.item]
        cell.mediaItemView.player = player
        
        if indexPath.item == currentPage{
            cell.mediaItemView.load()
        }
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? MediaItemCell{
            cell.mediaItemView.isDisplaying = true
            cell.mediaItemView.preload()
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? MediaItemCell{
            cell.mediaItemView.isDisplaying = false
            cell.mediaItemView.resetScrollViewZoom()
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let newPage = lroundf(Float(scrollView.contentOffset.x / scrollView.frame.width))
        if currentPage != newPage && newPage >= 0 && newPage < mediaItems.count{
            currentPage = newPage
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if mediaItems.count > 0{
            let cell = collectionView.cellForItem(at: IndexPath(item: currentPage, section: 0)) as! MediaItemCell
            cell.mediaItemView.stop()
            if isDisplayPageNumberEnabled{
                showPageNumbers()
            }
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if mediaItems.count > 0{
            checkPage()
            if isDisplayPageNumberEnabled{
                hidePageNumbers()
            }
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if mediaItems.count > 0{
            checkPage()
            if isDisplayPageNumberEnabled{
                hidePageNumbers()
            }
        }
    }
}

@objc public protocol MediaBrowserDelegate{
    @objc optional func mediaBrowser(_ browser: MediaBrowser, willMoving page: Int)
}





