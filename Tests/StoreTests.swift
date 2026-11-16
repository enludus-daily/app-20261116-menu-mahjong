import Testing
@testable import MenuMahjong

struct EntitlementsTests {
    let bundle = "com.enludus.daily.011"

    @Test func productIDsFollowTheBundleID() {
        #expect(ProductID.pro(bundleID: bundle) == "com.enludus.daily.011.pro")
        #expect(ProductID.pack("phrases", bundleID: bundle) == "com.enludus.daily.011.pack.phrases")
        #expect(ProductID.yearly(bundleID: bundle) == "com.enludus.daily.011.sub.yearly")
    }

    @Test func nothingOwnedIsNotPro() {
        let entitlements = Entitlements(proProductIDs: [ProductID.pro(bundleID: bundle)])
        #expect(!entitlements.isPro)
        #expect(!entitlements.owns(ProductID.pack("phrases", bundleID: bundle)))
    }

    @Test func proUnlocksEveryPack() {
        var entitlements = Entitlements(proProductIDs: [ProductID.pro(bundleID: bundle), ProductID.yearly(bundleID: bundle)])
        entitlements.replace(with: [ProductID.yearly(bundleID: bundle)])
        #expect(entitlements.isPro)
        #expect(entitlements.owns(ProductID.pack("phrases", bundleID: bundle)))
    }

    @Test func aPackAloneIsNotPro() {
        var entitlements = Entitlements(proProductIDs: [ProductID.pro(bundleID: bundle)])
        entitlements.replace(with: [ProductID.pack("phrases", bundleID: bundle)])
        #expect(!entitlements.isPro)
        #expect(entitlements.owns(ProductID.pack("phrases", bundleID: bundle)))
        #expect(!entitlements.owns(ProductID.pack("other", bundleID: bundle)))
    }

    @Test func refundRemovesTheRight() {
        var entitlements = Entitlements(proProductIDs: [ProductID.pro(bundleID: bundle)])
        entitlements.replace(with: [ProductID.pro(bundleID: bundle)])
        entitlements.replace(with: [])  // 返金・期限切れのあと、currentEntitlements から消える
        #expect(!entitlements.isPro)
    }
}
