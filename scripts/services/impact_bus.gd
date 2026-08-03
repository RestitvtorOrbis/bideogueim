extends Node

## A tiny UI-free transport for the ImpactEvent contract.

signal impact_received(event: ImpactEvent)

func emit_impact(event: ImpactEvent) -> void:
	if event == null:
		return
	impact_received.emit(event)
