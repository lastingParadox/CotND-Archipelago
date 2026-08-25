local apGrants = require("AP.scripts.items.apGrants")

-- "Spare" because Coupon is already a pool item, and AP item names have to be unique.
apGrants.defineItemFiller("APSpareCoupon", "MiscCoupon")
