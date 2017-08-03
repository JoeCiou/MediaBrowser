//
//  LoadingView.swift
//  MediaBrowser
//
//  Created by Joe on 2017/8/3.
//  Copyright © 2017年 Joe. All rights reserved.
//

import UIKit

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
