extends Node

signal unit_damaged(unit: Unit, info: DamageInfo)
signal unit_died(unit: Unit)
signal unit_thrown(unit: Unit, info: DamageInfo)
signal unit_landed(unit: Unit)
signal unit_wall_slammed(unit: Unit)
