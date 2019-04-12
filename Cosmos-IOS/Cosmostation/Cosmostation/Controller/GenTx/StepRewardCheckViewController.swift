//
//  StepRewardCheckViewController.swift
//  Cosmostation
//
//  Created by yongjoo on 12/04/2019.
//  Copyright © 2019 wannabit. All rights reserved.
//

import UIKit
import Alamofire
import BitcoinKit
import SwiftKeychainWrapper

class StepRewardCheckViewController: BaseViewController, PasswordViewDelegate{
    
    @IBOutlet weak var rewardAmoutLaebl: UILabel!
    @IBOutlet weak var feeAmountLabel: UILabel!
    @IBOutlet weak var fromValidatorLabel: UILabel!
    @IBOutlet weak var selfLabel: UILabel!
    @IBOutlet weak var recipientLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var beforeBtn: UIButton!
    @IBOutlet weak var confirmBtn: UIButton!

    var pageHolderVC: StepGenTxViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pageHolderVC = self.parent as? StepGenTxViewController
        
        
    }
    
    
    @IBAction func onClickConfirm(_ sender: Any) {
        let transition:CATransition = CATransition()
        transition.duration = 0.3
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.type = CATransitionType.moveIn
        transition.subtype = CATransitionSubtype.fromTop

        let passwordVC = UIStoryboard(name: "Password", bundle: nil).instantiateViewController(withIdentifier: "PasswordViewController") as! PasswordViewController
        self.navigationItem.title = ""
        self.navigationController!.view.layer.add(transition, forKey: kCATransition)
        passwordVC.mTarget = PASSWORD_ACTION_CHECK_TX
        passwordVC.resultDelegate = self
        self.navigationController?.pushViewController(passwordVC, animated: false)
    }
    
    
    @IBAction func onClickBack(_ sender: Any) {
        self.beforeBtn.isUserInteractionEnabled = false
        self.confirmBtn.isUserInteractionEnabled = false
        pageHolderVC.onBeforePage()
    }
    
    override func enableUserInteraction() {
        self.onUpdateView()
        self.beforeBtn.isUserInteractionEnabled = true
        self.confirmBtn.isUserInteractionEnabled = true
    }

    
    func onUpdateView() {
        rewardAmoutLaebl.attributedText = WUtils.displayAmout(pageHolderVC.mReward.reward_amount[0].amount, rewardAmoutLaebl.font, 6)
        feeAmountLabel.attributedText = WUtils.displayAmout((pageHolderVC.mFee?.amount[0].amount)!, feeAmountLabel.font, 6)
        fromValidatorLabel.text = pageHolderVC.mTargetValidator!.description.moniker
        recipientLabel.text = pageHolderVC.mRewardAddress
        recipientLabel.adjustsFontSizeToFitWidth = true
        if (pageHolderVC.mAccount?.account_address == pageHolderVC.mRewardAddress) {
            self.selfLabel.isHidden = false
        } else {
            self.selfLabel.isHidden = true
        }
        memoLabel.text = pageHolderVC.mMemo
    }
    
    func passwordResponse(result: Int) {
        if (result == PASSWORD_RESUKT_OK) {
            self.onGenGetRewardTx()
        }
    }
    
    func onGenGetRewardTx() {
        print("onGenGetRewardTx")
        self.showWaittingAlert()
        DispatchQueue.global().async {
            var stdTx:StdTx!
            guard let words = KeychainWrapper.standard.string(forKey: self.pageHolderVC.mAccount!.account_uuid.sha1())?.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ") else {
                print("ERROR words")
                return
            }
            
            do {
                let pKey = WKey.getCosmosKeyFromWords(mnemonic: words, path: UInt32(self.pageHolderVC.mAccount!.account_path)!)
                
                let msg = MsgGenerator.genGetRewardMsg(self.pageHolderVC.mAccount!.account_address,
                                                        self.pageHolderVC.mTargetValidator!.operator_address)
                
                var msgList = Array<Msg>()
                msgList.append(msg)
                
                let stdMsg = MsgGenerator.getToSignMsg(WUtils.getChainName(self.pageHolderVC.mAccount!.account_base_chain),
                                                       String(self.pageHolderVC.mAccount!.account_account_numner),
                                                       String(self.pageHolderVC.mAccount!.account_sequence_number),
                                                       msgList,
                                                       self.pageHolderVC.mFee!,
                                                       self.pageHolderVC.mMemo!)
                
                print("stdMsg ", stdMsg)
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                let data = try? encoder.encode(stdMsg)
                let rawResult = String(data:data!, encoding:.utf8)?.replacingOccurrences(of: "\\/", with: "/")
                print("rawResult ", rawResult)
                let rawData: Data? = rawResult!.data(using: .utf8)
                print("rawData ", rawData?.toHexString())
                let hash = Crypto.sha256(rawData!)
                print("hash ", hash.hexEncodedString())
                
                let signedData: Data? = try Crypto.sign(hash, privateKey: pKey.privateKey())
                print("signature ", WKey.convertSignature(signedData!))
                
                var genedSignature = Signature.init()
                var genPubkey =  PublicKey.init()
                genPubkey.type = COSMOS_KEY_TYPE_PUBLIC
                genPubkey.value = pKey.privateKey().publicKey().raw.base64EncodedString()
                genedSignature.pub_key = genPubkey
                genedSignature.signature = WKey.convertSignature(signedData!)
                
                var signatures: Array<Signature> = Array<Signature>()
                signatures.append(genedSignature)
                
                stdTx = MsgGenerator.genSignedTx(msgList,
                                                 self.pageHolderVC.mFee!,
                                                 self.pageHolderVC.mMemo!,
                                                 signatures)
                print("stdTx ", stdTx)
                
            } catch {
                print(error)
                
            }
            
            
            DispatchQueue.main.async(execute: {
                let postTx = PostTx.init("sync", stdTx.value)
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                let data = try? encoder.encode(postTx)
                
                do {
                    let params = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any]
                    let request = Alamofire.request(CSS_LCD_URL_BORAD_TX, method: .post, parameters: params, encoding: JSONEncoding.default, headers: [:])
                    request.responseJSON { response in
                        var txResult = [String:Any]()
                        switch response.result {
                        case .success(let res):
                            print("get reward ", res)
                            if let result = res as? [String : Any]  {
                                txResult = result
                            }
                        case .failure(let error):
                            print("et reward error ", error)
                        }
                        self.hideWaittingAlert()
                        txResult["type"] = COSMOS_MSG_TYPE_WITHDRAW_DEL
                        self.onStartTxResult(txResult)
                    }
                    
                    
                }catch {
                    print(error)
                }
            });
        }
    }
}