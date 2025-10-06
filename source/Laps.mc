using Toybox.Activity;
using Toybox.Lang;
using Toybox.AntPlus;

module ActiveLook {

    module Laps {

        function hasValue(object as Lang.Object, symbol as Lang.Symbol) as Lang.Boolean {
            return object has symbol && object[symbol] != null;
        }

        var isFrozen as Lang.Boolean = false;
        var useLapAverageSpeed as Lang.Boolean = false;

        var elapsedDistance as Lang.Float or Null = null;
        var totalAscent as Lang.Number or Null = null;
        var totalDescent as Lang.Number or Null = null;
        var calories as Lang.Number or Null = null;
        var sessionTimerTime as Lang.Number or Null = null;

        var lapNumber as Lang.Number = 0;
        var lapStartTimerTime as Lang.Number = 0;
        var lapStartElapsedDistance as Lang.Float = 0.0;
        var lapStartTotalAscent as Lang.Number = 0;
        var lapStartTotalDescent as Lang.Number = 0;
        var lapStartCalories as Lang.Number = 0;

        var lapAverageHeartRate as Lang.Float or Null = null;
        var lapAveragePower as Lang.Float or Null = null;
        var lapAveragePace as Lang.Float or Null = null;
        var lapAverageSpeed as Lang.Float or Null = null;
        var lapAverageCadence as Lang.Float or Null = null;
        var lapAverageAscentSpeed as Lang.Float or Null = null;
        var lapTimerTime as Lang.Number or Null = null;
        var lapChrono as Lang.Array<Lang.Number> or Null = null;
        var lapElapsedDistance as Lang.Float or Null = null;
        var lapTotalAscent as Lang.Number or Null = null;
        var lapTotalDescent as Lang.Number or Null = null;
        var lapCalories as Lang.Number or Null = null;

        var newLapAverageHeartRate as Lang.Float or Null = null;
        var newLapAveragePower as Lang.Float or Null = null;
        var newLapAverageCadence as Lang.Float or Null = null;
        var newLapAverageAscentSpeed as Lang.Float or Null = null;
        var newLapTimerTime as Lang.Number or Null = null;
        var newLapChrono as Lang.Array<Lang.Number> or Null = null;
        var newLapElapsedDistance as Lang.Float or Null = null;
        var newLapTotalAscent as Lang.Number or Null = null;
        var newLapTotalDescent as Lang.Number or Null = null;
        var newLapCalories as Lang.Number or Null = null;
        var newLapStartTimerTime as Lang.Number = 0;
        var newLapStartElapsedDistance as Lang.Float = 0.0;
        var newLapStartTotalAscent as Lang.Number = 0;
        var newLapStartTotalDescent as Lang.Number = 0;
        var newLapStartCalories as Lang.Number = 0;

        var __nbGroundContactTime as Lang.Number = 0;
        var __totalGroundContactTime as Lang.Number = 0;
        var __newNbGroundContactTime as Lang.Number = 0;
        var __newTotalGroundContactTime as Lang.Number = 0;
        var lapAverageGroundContactTime as Lang.Float?;
        
        var __nbVerticalOscillation as Lang.Number = 0;
        var __totalVerticalOscillation as Lang.Float = 0.0;
        var __newNbVerticalOscillation as Lang.Number = 0;
        var __newTotalVerticalOscillation as Lang.Float = 0.0;
        var lapAverageVerticalOscillation as Lang.Float?;

        var __nbStepLength as Lang.Number = 0;
        var __totalStepLength as Lang.Number = 0;
        var __newNbStepLength as Lang.Number = 0;
        var __newTotalStepLength as Lang.Number = 0;
        var lapAverageStepLength as Lang.Float?;

        function addLap(activityInfo as Activity.Info) as Void {
            lapNumber += 1;
            newLapStartElapsedDistance = hasValue(activityInfo, :elapsedDistance) ? activityInfo.elapsedDistance : 0.0;
            newLapStartTotalAscent = hasValue(activityInfo, :totalAscent) ? activityInfo.totalAscent : 0;
            newLapStartTotalDescent = hasValue(activityInfo, :totalDescent) ? activityInfo.totalDescent : 0;
            newLapStartCalories = hasValue(activityInfo, :calories) ? activityInfo.calories : 0;
            newLapStartTimerTime = hasValue(activityInfo, :timerTime) ? activityInfo.timerTime : 0;
            newLapAverageHeartRate = hasValue(activityInfo, :currentHeartRate) ? activityInfo.currentHeartRate : null;
            newLapAveragePower = AugmentedActivityInfo.power != null  ? AugmentedActivityInfo.power : null;
            newLapAverageCadence = hasValue(activityInfo, :currentCadence) ? activityInfo.currentCadence : null;
            __newNbGroundContactTime = 0;
            __newTotalGroundContactTime = 0;
            __newNbVerticalOscillation = 0;
            __newTotalVerticalOscillation = 0.0;
            __newNbStepLength = 0;
            __newTotalStepLength = 0;
        }

        function onSessionStart() as Void {
            lapNumber = 0;
            lapStartTimerTime = 0;
            lapStartElapsedDistance = 0.0;
            lapStartTotalAscent = 0;
            lapStartTotalDescent = 0;
            lapStartCalories = 0;
            __nbGroundContactTime = 0;
            __totalGroundContactTime = 0;
            __nbVerticalOscillation = 0;
            __totalVerticalOscillation = 0.0;
            __nbStepLength = 0;
            __totalStepLength = 0;
        }

        function accumulateRunningDynamics(runningDynamicsData as AntPlus.RunningDynamicsData?, frozen as Lang.Boolean) as Void{
            if (runningDynamicsData == null) {
                return;
            }
            
            var currentGroundContactTime = runningDynamicsData has :groundContactTime && runningDynamicsData.groundContactTime != null ? runningDynamicsData.groundContactTime : 0;
            var currentVerticalOscillation = runningDynamicsData has :verticalOscillation && runningDynamicsData.verticalOscillation != null ? runningDynamicsData.verticalOscillation : 0.0;
            var currentStepLength = runningDynamicsData has :stepLength && runningDynamicsData.stepLength != null ? runningDynamicsData.stepLength : 0;

            if(frozen){
                __newNbGroundContactTime ++;
                __newTotalGroundContactTime += currentGroundContactTime;
                __newNbVerticalOscillation ++;
                __newTotalVerticalOscillation += currentVerticalOscillation;
                __newNbStepLength ++;
                __newTotalStepLength += currentStepLength;
            } else {
                __nbGroundContactTime ++;
                __totalGroundContactTime += currentGroundContactTime;
                __nbVerticalOscillation ++;
                __totalVerticalOscillation += currentVerticalOscillation;
                __nbStepLength ++;
                __totalStepLength += currentStepLength;
            }

        }

        function computeRunningDynamics(runningDynamicsData as AntPlus.RunningDynamicsData) as Void{
            if (__nbGroundContactTime > 0) {
                lapAverageGroundContactTime = __totalGroundContactTime / __nbGroundContactTime;
            }
            if (__nbVerticalOscillation > 0) {
                lapAverageVerticalOscillation = __totalVerticalOscillation / __nbVerticalOscillation;
            }
            if (__nbStepLength > 0) {
                lapAverageStepLength = __totalStepLength / __nbStepLength;
            }
        }

        function compute(activityInfo as Activity.Info, frozen as Lang.Boolean) as Void {
            if(frozen){
                if(!isFrozen){
                    isFrozen = true;
                }
            } else {
                elapsedDistance = hasValue(activityInfo, :elapsedDistance) ? activityInfo.elapsedDistance : null;
                totalAscent = hasValue(activityInfo, :totalAscent) ? activityInfo.totalAscent : null;
                totalDescent = hasValue(activityInfo, :totalDescent) ? activityInfo.totalDescent : null;
                calories = hasValue(activityInfo, :calories) ? activityInfo.calories : null;
                sessionTimerTime = hasValue(activityInfo, :timerTime) ? activityInfo.timerTime : null;
                if(isFrozen){
                    isFrozen = false;
                    lapAverageHeartRate = newLapAverageHeartRate;
                    lapAveragePower = newLapAveragePower;
                    lapAveragePace = null;
                    lapAverageCadence = newLapAverageCadence;
                    lapAverageAscentSpeed = newLapAverageAscentSpeed;
                    lapElapsedDistance = newLapElapsedDistance;
                    lapTotalAscent = newLapTotalAscent;
                    lapTotalDescent = newLapTotalDescent;
                    lapCalories = newLapCalories;
                    lapChrono = newLapChrono;
                    lapStartTimerTime = newLapStartTimerTime;
                    lapStartElapsedDistance = newLapStartElapsedDistance;
                    lapStartTotalAscent = newLapStartTotalAscent;
                    lapStartTotalDescent = newLapStartTotalDescent;
                    lapStartCalories = newLapStartCalories;
                    __nbGroundContactTime = __newNbGroundContactTime;
                    __totalGroundContactTime = __newTotalGroundContactTime;
                    __nbVerticalOscillation = __newNbVerticalOscillation;
                    __totalVerticalOscillation = __newTotalVerticalOscillation;
                    __nbStepLength = __newNbStepLength;
                    __totalStepLength = __newTotalStepLength;
                }
            }

            lapElapsedDistance = elapsedDistance ? elapsedDistance - lapStartElapsedDistance : null;
            lapTotalAscent = totalAscent ? totalAscent - lapStartTotalAscent : null;
            lapTotalDescent = totalDescent ? totalDescent - lapStartTotalDescent : null;
            lapCalories = calories ? calories - lapStartCalories : null;
            if (sessionTimerTime != null && sessionTimerTime > lapStartTimerTime) {
                lapTimerTime = sessionTimerTime - lapStartTimerTime;
                var sec = (lapTimerTime + 500) / 1000;
                var mn = sec / 60;
                lapChrono = [mn / 60, mn % 60, sec % 60, lapTimerTime % 1000];
                if (lapTotalAscent != null) {
                    lapAverageAscentSpeed = lapTotalAscent / lapTimerTime;
                } else {
                    lapAverageAscentSpeed = null;
                }
                if(sec > 1){
                    var currentHeartRate = hasValue(activityInfo, :currentHeartRate) ? activityInfo.currentHeartRate : 0;
                    var currentPower = AugmentedActivityInfo.power != null ? AugmentedActivityInfo.power : 0;
                    var currentCadence = hasValue(activityInfo, :currentCadence) ? activityInfo.currentCadence : 0;
                    var currentAverageSpeed = hasValue(activityInfo, :averageSpeed) ? activityInfo.averageSpeed : 0;

                    if(!frozen){
                        if(lapAverageHeartRate == null){
                            lapAverageHeartRate = currentHeartRate;
                        }
                        if (lapAveragePower == null) {
                            lapAveragePower = currentPower;
                        }
                        if (lapAverageCadence == null) {
                            lapAverageCadence = currentCadence;
                        }
                    } else {
                        if(newLapAverageHeartRate == null){
                            newLapAverageHeartRate = currentHeartRate;
                        }
                        if (newLapAveragePower == null) {
                            newLapAveragePower = currentPower;
                        }
                        if (newLapAverageCadence == null) {
                            newLapAverageCadence = currentCadence;
                        }
                    }

                    if(frozen){
                        newLapAverageHeartRate = ((newLapAverageHeartRate * (sec - 1)) + currentHeartRate) / (sec * 1.0);
                        newLapAveragePower = ((newLapAveragePower * (sec - 1)) + currentPower) / (sec * 1.0);
                        newLapAverageCadence = ((newLapAverageCadence * (sec - 1)) + currentCadence) / (sec * 1.0);
                    } else {
                        lapAverageHeartRate = ((lapAverageHeartRate * (sec - 1)) + currentHeartRate) / (sec * 1.0);
                        lapAveragePower = ((lapAveragePower * (sec - 1)) + currentPower) / (sec * 1.0);
                        if(lapNumber == 0){
                            lapAverageSpeed = currentAverageSpeed;
                        } else {
                            lapAverageSpeed = (lapElapsedDistance ? lapElapsedDistance * 1.0 : 0.0) / (sec * 1.0);
                        }
                        lapAverageCadence = ((lapAverageCadence * (sec - 1)) + currentCadence) / (sec * 1.0);
                        if (lapAverageSpeed > 0.0) {
                            lapAveragePace = 1.0 / lapAverageSpeed;
                        } else {
                            lapAveragePace = null;
                        }
                    }
                }
            } else {
                lapAverageHeartRate = null;
                lapAveragePower = null;
                lapAveragePace = null;
                lapAverageSpeed = null;
                lapAverageCadence = null;
                lapAverageAscentSpeed = null;
                lapTimerTime = null;
                lapChrono = null;
            }
        }
    }

}