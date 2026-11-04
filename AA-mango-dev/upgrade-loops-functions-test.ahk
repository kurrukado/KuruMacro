UpgradeUnits() {

    global successfulCoordinates, PriorityUpgrade, priority1, priority2, priority3, priority4, priority5, priority6



    totalUnits := Map()

    upgradedCount := Map()



    ; Initialize counters

    for coord in successfulCoordinates {

        if (!totalUnits.Has(coord.slot)) {

            totalUnits[coord.slot] := 0

            upgradedCount[coord.slot] := 0

        }

        totalUnits[coord.slot]++

    }



    ProcessLog("Process to upgrading...")



    if (PriorityUpgrade.Value) {

        ProcessLog("Using priority system")



        ; Go through each priority level (1-6)

        for priorityNum in [1, 2, 3, 4, 5, 6] {

            ; Find which slot has this priority number

            for slot in [1, 2, 3, 4, 5, 6] {

                priority := "priority" slot

                priority := %priority%

                if (priority.Text = priorityNum) {

                    ; Skip if no units in this slot

                    hasUnitsInSlot := false

                    for coord in successfulCoordinates {

                        if (coord.slot = slot) {

                            hasUnitsInSlot := true

                            break

                        }

                    }



                    if (!hasUnitsInSlot) {

                        continue

                    }

                    ProcessLog("Priority upgrade for: " priorityNum " (slot " slot ")")



                    ; Keep upgrading current slot until all its units are maxed

                    while true {

                        slotDone := true



                        for index, coord in successfulCoordinates {

                            if (coord.slot = slot) {

                                slotDone := false

                                upgradeResult := UpgradeUnit(coord.x, coord.y, coord.slot)



                                if CheckForXp() {

                                    ProcessLog("Stage ended during upgrades, proceeding to results")

                                    successfulCoordinates := []

                                    MonitorStage()

                                    return

                                }



                                if (upgradeResult = "limit" || MaxUpgrade()) {

                                    upgradedCount[coord.slot]++

                                    ProcessLog((upgradeResult = "limit" ? "Max Level reached for: " : "Maxed out for: ") coord.slot " (" upgradedCount[coord.slot] "/" totalUnits[

                                        coord.slot] ")")

                                    successfulCoordinates.RemoveAt(index)

                                    CheckAbility()

                                    FixClick(325, 185) ;Close upg menu

                                    break

                                }



                                Sleep(200)

                                CheckAbility()

                                MahogoraAbility()

                                FixClick(560, 560) ; move click



                                ; click mahogora ability when upgrading

                                FixClick(239, 420)

                                FixClick(298, 420)

                                FixClick(358, 420)



                                Reconnect()

                                CheckEndAndRoute()

                                Wave40Reached()

                            }

                        }



                        if (slotDone || successfulCoordinates.Length = 0) {

                            ProcessLog("Upgrade Priority maxed for: " priorityNum)

                            break

                        }

                    }

                }

            }

        }

        ProcessLog("Priority Upgrade successfully")

        return MonitorStage()

    } else {

        ; Normal upgrade (no priority)

        while true {

            if (successfulCoordinates.Length == 0) {

                ProcessLog("All units reached max or configured Max Level, waiting for end stage...")

                return MonitorStage()

            }



            for index, coord in successfulCoordinates {

                upgradeResult := UpgradeUnit(coord.x, coord.y, coord.slot)



                if CheckForXp() {

                    ProcessLog("Stage ended, replay...")

                    successfulCoordinates := []

                    MonitorStage()

                    return

                }



                if (upgradeResult = "limit" || MaxUpgrade()) {

                    upgradedCount[coord.slot]++

                    ProcessLog((upgradeResult = "limit" ? "Max Level reached for: " : "Maxed out for: ") coord.slot " (" upgradedCount[coord.slot] "/" totalUnits[coord.slot] ")"

                    )

                    successfulCoordinates.RemoveAt(index)

                    FixClick(325, 185) ;Close upg menu

                    continue

                }



                Sleep(200)

                CheckAbility()

                MahogoraAbility()

                FixClick(560, 560) ; Move Click

                Reconnect()

                FixClick(560, 560)

                Wave40Reached()

                CheckEndAndRoute()

            }

        }

    }

}
