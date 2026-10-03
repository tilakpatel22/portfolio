extends Node
## AdMob: UMP consent -> init -> preload interstitial + rewarded ads.
## Rated for all ages (3+): every request is child-directed, under the age of consent and
## G-rated, so ads are never personalized and never use the advertising ID (COPPA / Families).
## Interstitial: at level transitions. Rewarded: opt-in "Bonus Lifebuoy" every 5 levels.

const INTERSTITIAL_ID := "ca-app-pub-1155049195805321/9701390845"
const REWARDED_ID := "ca-app-pub-1155049195805321/7047307349"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const MIN_INTERVAL := 30.0
const REWARD_EVERY := 5

var _enabled := OS.get_name() == "Android"
var _initialized := false
var _inter: InterstitialAd
var _reward: RewardedAd
var _loading := {"inter": false, "reward": false}
var _retry := {"inter": 4.0, "reward": 4.0}
var _last_shown := -1000.0
var _on_closed := Callable()
var _earned := false
var _showing := ""
var _content_cb := FullScreenContentCallback.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _enabled:
		return
	_content_cb.on_ad_dismissed_full_screen_content = _finish
	_content_cb.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: _finish()
	_request_consent()


## Debug builds (and the "test_ads" export) always use Google's test units to protect the AdMob account.
func _unit(kind: String) -> String:
	if OS.is_debug_build() or OS.has_feature("test_ads"):
		return TEST_INTERSTITIAL_ID if kind == "inter" else TEST_REWARDED_ID
	return INTERSTITIAL_ID if kind == "inter" else REWARDED_ID


func _request_consent() -> void:
	var params := ConsentRequestParameters.new()
	params.tag_for_under_age_of_consent = true
	UserMessagingPlatform.consent_information.update(params,
		_on_consent_info, func(_e: FormError) -> void: _init_sdk())


func _on_consent_info() -> void:
	if not UserMessagingPlatform.consent_information.get_is_consent_form_available():
		_init_sdk()
		return
	UserMessagingPlatform.load_consent_form(func(form: ConsentForm) -> void:
		if UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
			form.show(func(_e: FormError) -> void: _init_sdk())
		else:
			_init_sdk()
	, func(_e: FormError) -> void: _init_sdk())


func _init_sdk() -> void:
	if _initialized:
		return
	_initialized = true
	var config := RequestConfiguration.new()
	config.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
	config.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.TRUE
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	MobileAds.set_request_configuration(config)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_s: InitializationStatus) -> void:
		_load("inter")
		_load("reward")
	MobileAds.initialize(listener)


func _load(kind: String) -> void:
	if not _initialized or _loading[kind] or (_inter if kind == "inter" else _reward):
		return
	_loading[kind] = true
	if kind == "inter":
		var cb := InterstitialAdLoadCallback.new()
		cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
			_inter = ad
			_loaded(kind, ad)
		cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void: _failed(kind)
		InterstitialAdLoader.new().load(_unit(kind), AdRequest.new(), cb)
	else:
		var cb := RewardedAdLoadCallback.new()
		cb.on_ad_loaded = func(ad: RewardedAd) -> void:
			_reward = ad
			_loaded(kind, ad)
		cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void: _failed(kind)
		RewardedAdLoader.new().load(_unit(kind), AdRequest.new(), cb)


func _loaded(kind: String, ad: Object) -> void:
	_loading[kind] = false
	_retry[kind] = 4.0
	ad.full_screen_content_callback = _content_cb


func _failed(kind: String) -> void:
	_loading[kind] = false
	get_tree().create_timer(_retry[kind], true, false, true).timeout.connect(_load.bind(kind))
	_retry[kind] = minf(_retry[kind] * 2.0, 120.0)


## Shows an interstitial if one is ready (and not too soon), then calls on_closed.
func show_interstitial(on_closed: Callable) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _enabled or _inter == null or now - _last_shown < MIN_INTERVAL:
		_load("inter")
		on_closed.call()
		return
	_on_closed = on_closed
	_last_shown = now
	_showing = "inter"
	Audio.duck(true)
	_inter.show()


func is_reward_level(completed_level: int) -> bool:
	return completed_level % REWARD_EVERY == 0


func rewarded_ready() -> bool:
	return _enabled and _reward != null


## Opt-in rewarded ad. on_closed(earned: bool) is called when the ad closes.
func show_rewarded(on_closed: Callable) -> void:
	if not rewarded_ready():
		_load("reward")
		on_closed.call(false)
		return
	_earned = false
	_showing = "reward"
	_on_closed = on_closed
	_last_shown = Time.get_ticks_msec() / 1000.0
	Audio.duck(true)
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: _earned = true
	_reward.show(listener)


func _finish() -> void:
	Audio.duck(false)
	var kind := _showing
	_showing = ""
	if kind == "inter" and _inter:
		_inter.destroy()
		_inter = null
	elif kind == "reward" and _reward:
		_reward.destroy()
		_reward = null
	if _on_closed.is_valid():
		var cb := _on_closed
		_on_closed = Callable()
		if kind == "reward":
			cb.call_deferred(_earned)
		else:
			cb.call_deferred()
	_load("inter")
	_load("reward")


## Watchdog: if the app is back in front but the SDK never reported the ad closing,
## resume anyway so the game can never get stuck behind a lost callback.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _showing != "":
		var kind := _showing
		await get_tree().create_timer(2.0, true, false, true).timeout
		if _showing == kind:
			_finish()


func privacy_options_required() -> bool:
	return _enabled and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	if _enabled:
		UserMessagingPlatform.show_privacy_options_form(func(_e: FormError) -> void: pass)
