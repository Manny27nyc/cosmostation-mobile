//
//  Signer.swift
//  Cosmostation
//
//  Created by 정용주 on 2020/12/14.
//  Copyright © 2020 wannabit. All rights reserved.
//

import Foundation
import BitcoinKit

class Signer {
    
    static func genSignedSendTxV1(_ fromAddress: String, _ accountNum: String, _ sequenceNum: String,
                                  _ toAddress: String, _ amount: Array<Coin>, _ fee: Fee, _ memo: String,
                                  _ pKey: HDPrivateKey, _ chain: ChainType) -> StdTx {
        var msgList = Array<Msg>()
        var msg = Msg.init()
        var value = Msg.Value.init()
        if (chain == ChainType.COSMOS_TEST) {
            value.from_address = fromAddress
            value.to_address = toAddress
            let data = try? JSONEncoder().encode(amount)
            do { value.amount = try JSONDecoder().decode(AmountType.self, from:data!)
            } catch { print(error) }
            
            msg.type = COSMOS_MSG_TYPE_TRANSFER2
            msg.value = value
        }
        msgList.append(msg)
        
        let stdToSignMsg = getToSignMsg(WUtils.getChainId(chain), accountNum, sequenceNum, msgList, fee, memo)
        let signatureData = getSingleSignature(pKey, stdToSignMsg)
        let signatures = getSignatures(pKey, signatureData!, accountNum, sequenceNum)
        return genSignedTx(msgList, fee, memo, signatures)
    }
    
    
    static func getSingleSignature(_ pKey: HDPrivateKey, _ stdToSignMsg: StdSignMsg) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try? encoder.encode(stdToSignMsg)
        let rawResult = String(data:data!, encoding:.utf8)?.replacingOccurrences(of: "\\/", with: "/")
        let rawData: Data? = rawResult!.data(using: .utf8)
        let hash = Crypto.sha256(rawData!)
        return try? Crypto.sign(hash, privateKey: pKey.privateKey())
    }
    
    static func getSignatures(_ pKey: HDPrivateKey, _ signatureData: Data, _ accountNum: String, _ sequenceNum: String) -> Array<Signature> {
        var genedSignature = Signature.init()
        var genPubkey =  PublicKey.init()
        genPubkey.type = COSMOS_KEY_TYPE_PUBLIC
        genPubkey.value = pKey.privateKey().publicKey().raw.base64EncodedString()
        genedSignature.pub_key = genPubkey
        genedSignature.signature = WKey.convertSignature(signatureData)
        genedSignature.account_number = accountNum
        genedSignature.sequence = sequenceNum
        
        var signatures: Array<Signature> = Array<Signature>()
        signatures.append(genedSignature)
        return signatures
    }
    
    static func getToSignMsg(_ chain: String, _ accountNum: String, _ sequenceNum: String, _ msgs: Array<Msg>, _ fee: Fee, _ memo: String) -> StdSignMsg {
        var stdSignedMsg = StdSignMsg.init()
        
        stdSignedMsg.chain_id = chain
        stdSignedMsg.account_number = accountNum
        stdSignedMsg.sequence = sequenceNum
        stdSignedMsg.msgs = msgs
        stdSignedMsg.fee = fee
        stdSignedMsg.memo = memo
        
        return stdSignedMsg
    }
    
    static func genSignedTx(_ msgs: Array<Msg>, _ fee: Fee, _ memo: String, _ signatures: Array<Signature>) -> StdTx {
        let stdTx = StdTx.init()
        let value = StdTx.Value.init()
        
        value.msg = msgs
        value.fee = fee
        value.signatures = signatures
        value.memo = memo
        
        stdTx.type = COSMOS_AUTH_TYPE_STDTX
        stdTx.value = value
        
        return stdTx
    }
    
    static func getBroadCastParam(_ stdTx: StdTx) -> [String : Any]? {
        let postTx = PostTx.init("sync", stdTx.value)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try? encoder.encode(postTx)
        return try! JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any]
    }
}