class_name Shop
extends RefCounted

## 資金と、便利パーツのアンロック。
##
## ## 方針
## **必須パーツは無償、便利パーツは有償**。ここ(PRICES)に載っていないパーツは
## ステージが最初から使わせる。だからどのステージも「何も買っていない状態でクリアできる」。
##
## 鉱脈は手掘りできるし、分配器が無くても機械1台なら回る。買わなければ遅いだけで詰まない。
## この切り分けのおかげで、アンロック制を入れてもタイムアタックと喧嘩しない。
## ランクは「正しい道具を揃えたか」の指標になり、買い足すたびにベストタイムを更新しに戻る動機が生まれる。
##
## ## 収入
## - **クリア報酬(主)**: ステージの reward × ランク倍率。上のランクに初めて届いたときだけ差額が入る。
##   周回しても増えないので、稼ぎ目的の作業プレイが発生しない
## - **生産報酬(従)**: 搬出した個数 × アイテム単価。毎回もらえるが額は小さい
##
## 主が10倍近く効くので、資金の伸びは「新しいステージを開ける」「ランクを上げる」で決まる。

## 有償パーツと価格。ここに無いパーツは無償。
static var PRICES := {
	"drill": 120,
	"splitter": 220,
	"gearbox_down": 320,
	"gearbox_up": 420,
	"belt_fast": 600,
}

## ショップに並べる順。安い順・使う順。
static var ORDER := ["drill", "splitter", "gearbox_down", "gearbox_up", "belt_fast"]

## ランクごとの報酬倍率。
static var RANK_MULTIPLIER := {
	"クリア": 1.0,
	"BRONZE": 1.6,
	"SILVER": 2.4,
	"GOLD": 3.5,
}


static func is_purchasable(def_id: String) -> bool:
	return PRICES.has(def_id)


static func price(def_id: String) -> int:
	return int(PRICES.get(def_id, 0))


## そのパーツを使えるか。無償パーツは常に true。
static func is_owned(def_id: String) -> bool:
	if not is_purchasable(def_id):
		return true
	return SaveData.is_unlocked(def_id)


static func can_afford(def_id: String) -> bool:
	return SaveData.money() >= price(def_id)


## 購入する。買えたら true。
static func buy(def_id: String) -> bool:
	if not is_purchasable(def_id) or is_owned(def_id):
		return false
	if not SaveData.spend(price(def_id)):
		return false
	SaveData.unlock(def_id)
	return true


## そのランクを取ったときの累計クリア報酬。
static func clear_reward(stage: Dictionary, rank: String) -> int:
	var base := float(stage.get("reward", 100))
	return int(roundf(base * float(RANK_MULTIPLIER.get(rank, 1.0))))


## 搬出したぶんの生産報酬。毎回もらえる。
static func production_reward(stage: Dictionary) -> int:
	return int(stage.target_count) * Defs.item_value(String(stage.target_item))


## クリア時の精算。実際に増えた額を {clear, production, total} で返す。
static func settle(stage: Dictionary, rank: String) -> Dictionary:
	var stage_id := String(stage.id)
	var total_clear := clear_reward(stage, rank)
	var already := SaveData.paid_reward(stage_id)
	var clear_gain: int = maxi(total_clear - already, 0)
	if clear_gain > 0:
		SaveData.set_paid_reward(stage_id, total_clear)
	var production := production_reward(stage)
	SaveData.add_money(clear_gain + production)
	return {"clear": clear_gain, "production": production, "total": clear_gain + production}
