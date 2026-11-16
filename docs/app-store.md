# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.011 |
| アプリ名 | 献立マージャン / Menu Mahjong（AI が決めた。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/app-20261116-menu-mahjong/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261116-menu-mahjong/blob/main/PRIVACY.md |
| 年齢区分の答え | 麻雀の形だが**お金や景品を賭けない**（点は遊びの中だけ。換金・課金で点を買えない）。シミュレートされたギャンブル：「なし」が妥当と考えるが、麻雀を賭博の模擬と見るかは本人が判断（「まれ／軽度」にすると 12+ 前後）。暴力・Web 閲覧・生成 AI：なし |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：ゲーム（一人用の麻雀）で、懐中電灯・効果音・占いなどの種類ではない。料理の役 106 品と献立・買い物メモの仕組みを手で作った
- 既存のアプリとの意味のある違い：料理の絵柄の麻雀は 2 枚ずつ消すソリティアばかり。本物の手作り（ツモ・捨て・面子・役）で、和了りが作り方つきの献立と買い物メモになる
- 長く使える価値（4.2）：今日の一局（日替わりの配牌・連続日数）、料理の図鑑、献立帳と 1 週間の献立表
- 他社の名前・商標・見た目を使っていないか：使っていない。牌・看板・皿はすべて自作の図形。相手の料理人は架空の人物
- Apple Intelligence を使う場合、使えない端末での動き：使わない

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro（com.enludus.daily.011.pro、¥480、家族共有あり。StoreKit 2）
- 理由と勝算の表：README の「課金」

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ。App 内課金は Apple が扱う）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
