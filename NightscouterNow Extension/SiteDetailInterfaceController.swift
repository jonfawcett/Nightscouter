//
//  SiteDetailInterfaceController.swift
//  Nightscouter
//
//  Created by Peter Ina on 11/8/15.
//  Copyright © 2015 Peter Ina. All rights reserved.
//

import WatchKit
import Foundation
import NightscouterWatchOSKit

protocol SiteDetailViewDidUpdateItemDelegate {
    func didUpdateItem(site: Site)
}

class SiteDetailInterfaceController: WKInterfaceController {
    
    @IBOutlet var compassGroup: WKInterfaceGroup!
    @IBOutlet var detailGroup: WKInterfaceGroup!
    @IBOutlet var lastUpdateLabel: WKInterfaceLabel!
    @IBOutlet var lastUpdateHeader: WKInterfaceLabel!
    @IBOutlet var batteryLabel: WKInterfaceLabel!
    @IBOutlet var batteryHeader: WKInterfaceLabel!
    @IBOutlet var compassImage: WKInterfaceImage!
    
    var nsApi: NightscoutAPIClient?
    
    var task: NSURLSessionDataTask?
    
    var isActive: Bool = false
    
    var delegate: SiteDetailViewDidUpdateItemDelegate?
    
    var timer: NSTimer = NSTimer()
    
    var site: Site? {
        didSet {
            
            print("didSet Site? in SiteDetailInterfaceController")
            updateData()
        }
    }
    var lastUpdatedTime: NSDate?
    
    override func willActivate() {
        super.willActivate()
        print("willActivate")
        
        let image = NSAssetKitWatchOS.imageOfWatchFace()
        
        compassImage.setImage(image)

        self.isActive = true
        
        timer = NSTimer.scheduledTimerWithTimeInterval(240.0, target: self, selector: Selector("updateData"), userInfo: nil, repeats: true)

    }
    
    override func didDeactivate() {
        super.didDeactivate()
        print("didDeactivate \(self)")
        
        self.isActive = false
        if let t = self.nsApi?.task {
            if t.state == NSURLSessionTaskState.Running {
                t.cancel()
            }
        }
        
        timer.invalidate()
    }
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        if let site = context as? Site { self.site = site }
        
        if let site = context!["site"] as? Site { self.site = site }
        
        if let delegate = context!["delegate"] as? SiteDetailViewDidUpdateItemDelegate { self.delegate = delegate }
        
    }
    
    func updateData(){
        
        guard let site = self.site else {
            return
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            // Start up the API
            self.nsApi = NightscoutAPIClient(url: site.url)
            
            if (self.lastUpdatedTime?.timeIntervalSinceNow > 120) || self.lastUpdatedTime == nil {
                
                // Get settings for a given site.
                // print("Loading data for \(site.url!)")
                self.nsApi!.fetchServerConfiguration { (result) -> Void in
                    switch (result) {
                    case let .Error(error):
                        // display error message
                        print("\(__FUNCTION__) ERROR recieved: \(error)")
                    case let .Value(boxedConfiguration):
                        let configuration:ServerConfiguration = boxedConfiguration.value
                        // do something with user
                        self.nsApi!.fetchDataForWatchEntry({ (watchEntry, watchEntryErrorCode) -> Void in
                            // Get back on the main queue to update the user interface
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                
                                // print("recieved data: { configuration: \(configuration), watchEntry: \(watchEntry) })")
                                
                                site.configuration = configuration
                                site.watchEntry = watchEntry
                                self.lastUpdatedTime = site.lastConnectedDate
                                self.delegate?.didUpdateItem(site)
                                self.configureView()
                            })
                        })
                    }
                }
            }
        }
    }
    

    func configureView(){
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            let watchModel = WatchModel(fromSite: self.site!)!
            
            let compassAlpha: CGFloat = watchModel.warn ? 0.5 : 1.0
            
            let frame = self.contentFrame
            let smallest = min(min(frame.height, frame.width), 134)
            let groupFrame = CGRect(x: 0, y: 0, width: smallest, height: smallest)
            
            let image = NSAssetKitWatchOS.imageOfWatchFace(arrowTintColor: watchModel.sgvColor, rawColor: watchModel.rawColor, isDoubleUp: watchModel.isDoubleUp, isArrowVisible: watchModel.isArrowVisible, isRawEnabled: watchModel.rawVisible, deltaString: watchModel.deltaString, sgvString: watchModel.sgvString, rawString: watchModel.rawString, angle: watchModel.angle, watchFrame: groupFrame)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                
                self.setTitle(watchModel.displayName)
            
                self.compassImage.setAlpha(compassAlpha)
                self.compassImage.setImage(image)
                self.setTitle(watchModel.displayName)
                
                // Battery label
                self.batteryLabel.setText(watchModel.batteryString)
                self.batteryLabel.setTextColor(watchModel.batteryColor)
                
                // Last reading label
                self.lastUpdateLabel.setText(watchModel.lastReadingString)
                self.lastUpdateLabel.setTextColor(watchModel.lastReadingColor)
                
            })
            
            
        }
    }
    
}

