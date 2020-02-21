//
//  BarcodeScannerViewController.swift
//  barcode_scan
//
//  Created by Julian Finkler on 20.02.20.
//

import Foundation
import MTBBarcodeScanner

class BarcodeScannerViewController: UIViewController {
    private var previewView: UIView?
    private var scanRect: ScannerOverlay?
    private var scanner: MTBBarcodeScanner?
    var delegate: BarcodeScannerViewControllerDelegate?
    
    private var device: AVCaptureDevice? {
        return AVCaptureDevice.default(for: .video)
    }
    
    private var isFlashOn: Bool {
        return device != nil && (device?.flashMode == AVCaptureDevice.FlashMode.on || device?.torchMode == .on)
    }
    
    private var hasTorch: Bool {
        return device?.hasTorch ?? false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if targetEnvironment(simulator)
        view.backgroundColor = .lightGray
        #endif
        
        previewView = UIView(frame: view.bounds)
        if let previewView = previewView {
            previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(previewView)
        }
        setupScanRect(view.bounds)
        scanner = MTBBarcodeScanner(previewView: previewView)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(cancel)
        )
        updateToggleFlashButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if scanner!.isScanning() {
            scanner!.stopScanning()
        }
        scanRect?.startAnimating()
        MTBBarcodeScanner.requestCameraPermission(success: { success in
            if success {
                self.startScan()
            } else {
                #if !targetEnvironment(simulator)
                self.errorResult(errorCode: "PERMISSION_NOT_GRANTED")
                #endif
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        scanner?.stopScanning()
        scanRect?.stopAnimating()
        
        if isFlashOn {
            setFlashState(false)
        }
        
        super.viewWillDisappear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        setupScanRect(CGRect(origin: CGPoint(x: 0, y:0),
                             size: size
        ))
    }
    
    private func setupScanRect(_ bounds: CGRect) {
        if scanRect != nil {
            scanRect?.stopAnimating()
            scanRect?.removeFromSuperview()
        }
        scanRect = ScannerOverlay(frame: bounds)
        if let scanRect = scanRect {
            scanRect.translatesAutoresizingMaskIntoConstraints = false
            scanRect.backgroundColor = UIColor.clear
            view.addSubview(scanRect)
            scanRect.startAnimating()
        }
    }
    
    private func startScan() {
        do {
            try scanner!.startScanning(resultBlock: { codes in
                if let code = codes?.first {
                    self.scanner!.stopScanning()
                    self.delegate?.didScanBarcodeWithResult(self, barcode: code.stringValue ?? "")
                    self.dismiss(animated: false)
                }
            })
        } catch {
            errorResult(errorCode: "\(error)")
        }
    }
    
    @objc private func cancel() {
        errorResult(errorCode: "USER_CANCELED")
    }
    
    @objc private func onToggleFlash() {
        setFlashState(!isFlashOn)
        updateToggleFlashButton()
    }
    
    private func updateToggleFlashButton() {
        if !hasTorch {
            return
        }
        
        let buttonText = isFlashOn ? "Flash Off" : "Flash On"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: buttonText,
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(onToggleFlash)
        )
    }
    
    private func setFlashState(_ on: Bool) {
        if let device = device {
            guard device.hasFlash && device.hasTorch else {
                return
            }
            
            do {
                try device.lockForConfiguration()
            } catch {
                return
            }
            
            device.flashMode = on ? .on : .off
            device.torchMode = on ? .on : .off
            
            device.unlockForConfiguration()
        }
    }
    
    private func errorResult(errorCode: String){
        delegate?.didFailWithErrorCode(self, errorCode: errorCode)
        dismiss(animated: false)
    }
}
