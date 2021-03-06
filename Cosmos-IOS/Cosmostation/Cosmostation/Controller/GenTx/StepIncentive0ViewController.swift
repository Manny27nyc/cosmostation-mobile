//
//  StepIncentive1ViewController.swift
//  Cosmostation
//
//  Created by 정용주 on 2020/05/26.
//  Copyright © 2020 wannabit. All rights reserved.
//

import UIKit

class StepIncentive0ViewController: BaseViewController {
    
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnNext: UIButton!
    @IBOutlet weak var incentiveAmount: UILabel!
    @IBOutlet weak var incentiveDenom: UILabel!
    @IBOutlet weak var lockup: UILabel!
    @IBOutlet weak var receivableAmount: UILabel!
    @IBOutlet weak var receivableDenom: UILabel!
    
    @IBOutlet weak var option1Btn: UIButton!
    @IBOutlet weak var option2Btn: UIButton!
    @IBOutlet weak var option3Btn: UIButton!
    
    var pageHolderVC: StepGenTxViewController!
    var mIncentiveType: String?
    var mIncentiveRewardParam: KavaIncentiveParam2.IncentiveRewardParam?
    var mAllIncentiveAmount = NSDecimalNumber.zero
    var mKavaClaimMultiplier = Array<KavaClaimMultiplier>()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.account = BaseData.instance.selectAccountById(id: BaseData.instance.getRecentAccountId())
        self.chainType = WUtils.getChainType(account!.account_base_chain)
        self.pageHolderVC = self.parent as? StepGenTxViewController
        self.mIncentiveType = pageHolderVC.mIncentiveType
        
        mIncentiveRewardParam = BaseData.instance.mIncentiveParam2?.result.rewards.filter({ $0.collateral_type == mIncentiveType}).first
        
        let incentiveClaimables = BaseData.instance.mIncentiveClaimables
        for incentive in incentiveClaimables {
            if (mIncentiveType == incentive.claim.collateral_type && incentive.claimable) {
                mAllIncentiveAmount = mAllIncentiveAmount.adding(NSDecimalNumber.init(string: incentive.claim.reward.amount))
            }
        }
        WUtils.showCoinDp(KAVA_MAIN_DENOM, mAllIncentiveAmount.stringValue, incentiveDenom, incentiveAmount, chainType!)
        if let multipliers = mIncentiveRewardParam?.claim_multipliers {
            mKavaClaimMultiplier = multipliers
            if (mKavaClaimMultiplier.count > 0) {
                option1Btn.isHidden = false
                option1Btn.setTitle(multipliers[0].name.uppercased(), for: .normal)
            }
            if (mKavaClaimMultiplier.count > 1) {
                option2Btn.isHidden = false
                option2Btn.setTitle(multipliers[1].name.uppercased(), for: .normal)
            }
            if (mKavaClaimMultiplier.count > 2) {
                option3Btn.isHidden = false
                option3Btn.setTitle(multipliers[2].name.uppercased(), for: .normal)
            }
        }
    }
    
    override func enableUserInteraction() {
        initBtns()
        pageHolderVC.mIncentiveMultiplier = nil
        self.btnCancel.isUserInteractionEnabled = true
        self.btnNext.isUserInteractionEnabled = true
    }
    
    @IBAction func onClickOption1(_ sender: UIButton) {
        initBtns()
        sender.borderColor = UIColor.white
        lockup.text = mKavaClaimMultiplier[0].months_lockup + " Month"
        let receiveAmount = mAllIncentiveAmount.multiplying(by: NSDecimalNumber.init(string: mKavaClaimMultiplier[0].factor), withBehavior: WUtils.handler0)
        WUtils.showCoinDp(KAVA_MAIN_DENOM, receiveAmount.stringValue, receivableDenom, receivableAmount, chainType!)
        pageHolderVC.mIncentiveMultiplier = mKavaClaimMultiplier[0]
        pageHolderVC.mIncentiveReceivable = receiveAmount
    }
    
    @IBAction func onClickOption2(_ sender: UIButton) {
        initBtns()
        sender.borderColor = UIColor.white
        lockup.text = mKavaClaimMultiplier[1].months_lockup + " Month"
        let receiveAmount = mAllIncentiveAmount.multiplying(by: NSDecimalNumber.init(string: mKavaClaimMultiplier[1].factor), withBehavior: WUtils.handler0)
        WUtils.showCoinDp(KAVA_MAIN_DENOM, receiveAmount.stringValue, receivableDenom, receivableAmount, chainType!)
        pageHolderVC.mIncentiveMultiplier = mKavaClaimMultiplier[1]
        pageHolderVC.mIncentiveReceivable = receiveAmount
    }
    
    @IBAction func onClickOption3(_ sender: UIButton) {
        initBtns()
        sender.borderColor = UIColor.white
        lockup.text = mKavaClaimMultiplier[1].months_lockup + " Month"
        let receiveAmount = mAllIncentiveAmount.multiplying(by: NSDecimalNumber.init(string: mKavaClaimMultiplier[2].factor), withBehavior: WUtils.handler0)
        WUtils.showCoinDp(KAVA_MAIN_DENOM, receiveAmount.stringValue, receivableDenom, receivableAmount, chainType!)
        pageHolderVC.mIncentiveMultiplier = mKavaClaimMultiplier[2]
        pageHolderVC.mIncentiveReceivable = receiveAmount
    }
    
    @IBAction func onClickCancel(_ sender: UIButton) {
        self.btnCancel.isUserInteractionEnabled = false
        self.btnNext.isUserInteractionEnabled = false
        pageHolderVC.onBeforePage()
    }
    
    @IBAction func onClickNext(_ sender: UIButton) {
        if (pageHolderVC.mIncentiveMultiplier != nil) {
            self.btnCancel.isUserInteractionEnabled = false
            self.btnNext.isUserInteractionEnabled = false
            pageHolderVC.onNextPage()
            
        } else {
            self.onShowToast(NSLocalizedString("error_no_opinion", comment: ""))
            return
        }
    }
    
    func initBtns() {
        option1Btn.borderColor = UIColor(hexString: "#4b4f54")
        option2Btn.borderColor = UIColor(hexString: "#4b4f54")
        option3Btn.borderColor = UIColor(hexString: "#4b4f54")
    }
}
