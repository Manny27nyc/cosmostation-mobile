//
//  StepUndelegateCheckViewController.swift
//  Cosmostation
//
//  Created by yongjoo on 12/04/2019.
//  Copyright © 2019 wannabit. All rights reserved.
//

import UIKit
import Alamofire
import BitcoinKit
import SwiftKeychainWrapper

class StepUndelegateCheckViewController: BaseViewController, PasswordViewDelegate{
    
    @IBOutlet weak var toUnDelegateAmoutLaebl: UILabel!
    @IBOutlet weak var toUndelegateDenomLabel: UILabel!
    @IBOutlet weak var feeAmountLabel: UILabel!
    @IBOutlet weak var feeDenomLabel: UILabel!
    @IBOutlet weak var targetValidatorLabel: UILabel!
    @IBOutlet weak var expectedDateLabel: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var beforeBtn: UIButton!
    @IBOutlet weak var confirmBtn: UIButton!
    
    var pageHolderVC: StepGenTxViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        pageHolderVC = self.parent as? StepGenTxViewController
        WUtils.setDenomTitle(pageHolderVC.userChain!, toUndelegateDenomLabel)
        WUtils.setDenomTitle(pageHolderVC.userChain!, feeDenomLabel)
    }
    
    
    @IBAction func onClickConfirm(_ sender: Any) {
        self.beforeBtn.isUserInteractionEnabled = false
        self.confirmBtn.isUserInteractionEnabled = false

        let passwordVC = UIStoryboard(name: "Password", bundle: nil).instantiateViewController(withIdentifier: "PasswordViewController") as! PasswordViewController
        self.navigationItem.title = ""
        self.navigationController!.view.layer.add(WUtils.getPasswordAni(), forKey: kCATransition)
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
        if (pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_COSMOS_MAIN) {
            toUnDelegateAmoutLaebl.attributedText = WUtils.displayAmount((pageHolderVC.mToUndelegateAmount?.amount)!, toUnDelegateAmoutLaebl.font, 6, pageHolderVC.userChain!)
            feeAmountLabel.attributedText = WUtils.displayAmount((pageHolderVC.mFee?.amount[0].amount)!, feeAmountLabel.font, 6, pageHolderVC.userChain!)
        } else if (pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_IRIS_MAIN) {
            toUnDelegateAmoutLaebl.attributedText = WUtils.displayAmount((pageHolderVC.mToUndelegateAmount?.amount)!, toUnDelegateAmoutLaebl.font, 18, pageHolderVC.userChain!)
            feeAmountLabel.attributedText = WUtils.displayAmount((pageHolderVC.mFee?.amount[0].amount)!, feeAmountLabel.font, 18, pageHolderVC.userChain!)
        }
        targetValidatorLabel.text = pageHolderVC.mTargetValidator?.description.moniker
        memoLabel.text = pageHolderVC.mMemo
        expectedDateLabel.text = WUtils.unbondingDateFromNow() + " (21days after)"
    }

    func passwordResponse(result: Int) {
        if (result == PASSWORD_RESUKT_OK) {
            self.onFetchAccountInfo(pageHolderVC.mAccount!)
        }
    }
    
    func onFetchAccountInfo(_ account: Account) {
        self.showWaittingAlert()
        var request: DataRequest?
        if (pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_COSMOS_MAIN) {
            request = Alamofire.request(CSS_LCD_URL_ACCOUNT_INFO + account.account_address, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:])
        } else if (pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_IRIS_MAIN) {
            request = Alamofire.request(IRIS_LCD_URL_ACCOUNT_INFO + account.account_address, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:])
        }
        request?.responseJSON { (response) in
            switch response.result {
            case .success(let res):
                guard let info = res as? [String : Any] else {
                    _ = BaseData.instance.deleteBalance(account: account)
                    self.hideWaittingAlert()
                    self.onShowToast(NSLocalizedString("error_network", comment: ""))
                    return
                }
                let accountInfo = AccountInfo.init(info)
                _ = BaseData.instance.updateAccount(WUtils.getAccountWithAccountInfo(account, accountInfo))
                BaseData.instance.updateBalances(account.account_id, WUtils.getBalancesWithAccountInfo(account, accountInfo))
                self.onGenUnDelegateTx()
                
            case .failure(let _):
                self.hideWaittingAlert()
                self.onShowToast(NSLocalizedString("error_network", comment: ""))
            }
        }
    }
    
    func onGenUnDelegateTx() {
        DispatchQueue.global().async {
            var stdTx:StdTx!
            guard let words = KeychainWrapper.standard.string(forKey: self.pageHolderVC.mAccount!.account_uuid.sha1())?.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ") else {
                return
            }
            
            do {
                let pKey = WKey.getHDKeyFromWords(mnemonic: words, path: UInt32(self.pageHolderVC.mAccount!.account_path)!)
                
                let msg = MsgGenerator.genUndelegateMsg(self.pageHolderVC.mAccount!.account_address,
                                                        self.pageHolderVC.mTargetValidator!.operator_address,
                                                        self.pageHolderVC.mToUndelegateAmount!,
                                                        self.pageHolderVC.userChain!)
                
                var msgList = Array<Msg>()
                msgList.append(msg)
                
                if (self.pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_COSMOS_MAIN) {
                    let stdMsg = MsgGenerator.getToSignMsg(WUtils.getChainName(self.pageHolderVC.mAccount!.account_base_chain),
                                                           String(self.pageHolderVC.mAccount!.account_account_numner),
                                                           String(self.pageHolderVC.mAccount!.account_sequence_number),
                                                           msgList,
                                                           self.pageHolderVC.mFee!,
                                                           self.pageHolderVC.mMemo!)
                    
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .sortedKeys
                    let data = try? encoder.encode(stdMsg)
                    let rawResult = String(data:data!, encoding:.utf8)?.replacingOccurrences(of: "\\/", with: "/")
                    let rawData: Data? = rawResult!.data(using: .utf8)
                    let hash = Crypto.sha256(rawData!)
                    
                    let signedData: Data? = try Crypto.sign(hash, privateKey: pKey.privateKey())
                    
                    var genedSignature = Signature.init()
                    var genPubkey =  PublicKey.init()
                    genPubkey.type = COSMOS_KEY_TYPE_PUBLIC
                    genPubkey.value = pKey.privateKey().publicKey().raw.base64EncodedString()
                    genedSignature.pub_key = genPubkey
                    genedSignature.signature = WKey.convertSignature(signedData!)
                    genedSignature.account_number = String(self.pageHolderVC.mAccount!.account_account_numner)
                    genedSignature.sequence = String(self.pageHolderVC.mAccount!.account_sequence_number)
                    
                    var signatures: Array<Signature> = Array<Signature>()
                    signatures.append(genedSignature)
                    
                    stdTx = MsgGenerator.genSignedTx(msgList, self.pageHolderVC.mFee!, self.pageHolderVC.mMemo!, signatures)
                    
                } else if (self.pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_IRIS_MAIN) {
                    let irisStdMsg = MsgGenerator.getIrisToSignMsg(WUtils.getChainName(self.pageHolderVC.mAccount!.account_base_chain),
                                                                   String(self.pageHolderVC.mAccount!.account_account_numner),
                                                                   String(self.pageHolderVC.mAccount!.account_sequence_number),
                                                                   msgList,
                                                                   self.pageHolderVC.mFee!,
                                                                   self.pageHolderVC.mMemo!)
                    
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .sortedKeys
                    let data = try? encoder.encode(irisStdMsg)
                    let rawResult = String(data:data!, encoding:.utf8)?.replacingOccurrences(of: "\\/", with: "/")
                    let rawData: Data? = rawResult!.data(using: .utf8)
                    let hash = Crypto.sha256(rawData!)
                    let signedData: Data? = try Crypto.sign(hash, privateKey: pKey.privateKey())
                    
                    var genedSignature = Signature.init()
                    var genPubkey =  PublicKey.init()
                    genPubkey.type = COSMOS_KEY_TYPE_PUBLIC
                    genPubkey.value = pKey.privateKey().publicKey().raw.base64EncodedString()
                    genedSignature.pub_key = genPubkey
                    genedSignature.signature = WKey.convertSignature(signedData!)
                    genedSignature.account_number = String(self.pageHolderVC.mAccount!.account_account_numner)
                    genedSignature.sequence = String(self.pageHolderVC.mAccount!.account_sequence_number)
                    
                    var signatures: Array<Signature> = Array<Signature>()
                    signatures.append(genedSignature)
                    
                    stdTx = MsgGenerator.genSignedTx(msgList, self.pageHolderVC.mFee!, self.pageHolderVC.mMemo!, signatures)
                }
                
            } catch {
                if(SHOW_LOG) { print(error) }
            }
            
            DispatchQueue.main.async(execute: {
                let postTx = PostTx.init("sync", stdTx.value)
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                let data = try? encoder.encode(postTx)
                do {
                    let params = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any]
                    var url = "";
                    if (self.pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_COSMOS_MAIN) {
                        url = CSS_LCD_URL_BORAD_TX
                    } else if (self.pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_IRIS_MAIN) {
                        url = IRIS_LCD_URL_BORAD_TX
                    }
                    let request = Alamofire.request(url, method: .post, parameters: params, encoding: JSONEncoding.default, headers: [:])
                    request.responseJSON { response in
                        var txResult = [String:Any]()
                        switch response.result {
                        case .success(let res):
//                            print("undelegate ", res)
                            if let result = res as? [String : Any]  {
                                txResult = result
                            }
                        case .failure(let error):
                            if(SHOW_LOG) {
                                print("undelegate error ", error)
                            }
                            if (response.response?.statusCode == 500) {
                                txResult["net_error"] = 500
                            }
                            
                        }
                        if (self.waitAlert != nil) {
                            self.waitAlert?.dismiss(animated: true, completion: {
                                if (self.pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_COSMOS_MAIN) {
                                    txResult["type"] = COSMOS_MSG_TYPE_UNDELEGATE2
                                } else if (self.pageHolderVC.userChain! == ChainType.SUPPORT_CHAIN_IRIS_MAIN) {
                                    txResult["type"] = IRIS_MSG_TYPE_UNDELEGATE
                                }
                                self.onStartTxResult(txResult)
                            })
                        }
                    }

                } catch {
                    if(SHOW_LOG) { print(error) }
                }
            });
        }
    }
}
