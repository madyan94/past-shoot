/**
 * PastShoot.mq4
 * Intelligent MQL4 script that takes screenshots of when a similar pattern
 * has formed in the past for traders to anticipate the future price action.
 *
 * Copyright 2015, Madyan Al-Jazaeri
 */

#property strict
#property copyright   "Copyright 2015, Madyan Al-Jazaeri"
#property link        "https://github.com/madyan94"
#property description "Intelligent MQL4 script that takes screenshots of when a similar pattern has formed in the past."
#property version     "1.00"
#property script_show_inputs

input int InitBar = 14;
input int MaxPatternMatch = 20;
input int PatternBars = 12;
input int MinBarSim = 50;
input int MinPatternSim = 70;
input int PredictionBars = 8;

input string Folder = "PastShoot-Output";
input int    Width  = 1154;
input int    Height = 600;

void OnStart() {
    ChartSetInteger(0, CHART_AUTOSCROLL, false);
    ObjectsDeleteAll(0, "PatternMatch[");
    Comment("");

    int align = ALIGN_LEFT;

    double totalDiffInHighest = 0;
    double totalDiffInLowest  = 0;
    int patternMatch = 0;
    int dayBars = 1440 / Period(); // 24 * 60 = 1440
    int i = dayBars + InitBar;
    while (patternMatch < MaxPatternMatch && i < Bars - (PatternBars + InitBar - 1) - 4) {
        for (int j = i - 2; j <= i + 2; j++) {
            int sim = comparePattern(j, PatternBars, MinBarSim, InitBar);
            if (sim > MinPatternSim) {
                totalDiffInHighest += predictDiffInHighest(j, PredictionBars);
                totalDiffInLowest  += predictDiffInLowest (j, PredictionBars);
                patternMatch++;

                Comment("sim = " + string(sim) + "%");
                ObjectCreate("PatternMatch[" + string(j) + "]", OBJ_VLINE, 0, Time[j], 0);
                ChartNavigate(0, CHART_END, -1 * j);
                ChartScreenShot(0, Folder + "\\" + string(patternMatch) + ".png", Width, Height, align);
            }
        }

        i += dayBars;
    }

    double predictedHighest = High[1 + InitBar] + (totalDiffInHighest / patternMatch); // high + average point change
    double predictedLowest  = Low [1 + InitBar] + (totalDiffInLowest  / patternMatch); // low  + average point change

    ObjectCreate("PatternMatch[" + string(InitBar) + "]", OBJ_VLINE, 0, Time[InitBar], 0);
    ChartNavigate(0, CHART_END, -1 * InitBar);
    ChartScreenShot(0, Folder + "\\0.png", Width, Height, align); // Print(GetLastError());
    ObjectCreate("predictedHighest", OBJ_HLINE, 0, 0, predictedHighest);
    ObjectCreate("predictedLowest" , OBJ_HLINE, 0, 0, predictedLowest);
}

int comparePattern(int endBar, int patternBars = 8, int minBarSim = 60, int shift = 0) {
    int total = 0;

    ObjectsDeleteAll(0, "barSim[");
    for (int i = patternBars; i > 0; i--) {
        int barSim = compareBars(i + shift, endBar + i);

        ObjectCreate("barSim[" + string(endBar + i) + "]", OBJ_TEXT, 0, Time[endBar + i], High[endBar + i] + 0.00075);
        ObjectSetText("barSim[" + string(endBar + i) + "]", string(barSim), 10, "Arial Black", clrBlue);

        if (barSim < minBarSim) {
            return -1;
        }
        total += barSim;
    }

    return (total / patternBars); // average
}

int compareBars(int a, int b) {
    int total;

    // polarity
    bool aIsBullish = Close[a] - Open[a] > 0;
    bool bIsBullish = Close[b] - Open[b] > 0;
    total += (aIsBullish && bIsBullish) || (!aIsBullish && !bIsBullish) ? 100 : 0;

    // bar length
    double aLength = High[a] - Low[a];
    aLength = aLength == 0 ? 0.00001 : aLength;
    double bLength = High[b] - Low[b];
    bLength = bLength == 0 ? 0.00001 : bLength;
    total += calculateSimilarity(aLength, bLength);

    // upper shadow
    double aUpperShadow = (High[a] - (aIsBullish ? Close[a] : Open[a])) / aLength;
    double bUpperShadow = (High[b] - (bIsBullish ? Close[b] : Open[b])) / bLength;
    total += calculateSimilarity(aUpperShadow, bUpperShadow);

    // lower shadow
    double aLowerShadow = ((aIsBullish ? Open[a] : Close[a]) - Low[a]) / aLength;
    double bLowerShadow = ((bIsBullish ? Open[b] : Close[b]) - Low[b]) / bLength;
    total += calculateSimilarity(aLowerShadow, bLowerShadow);

    // body
    double aBody = MathAbs(Open[a] - Close[a]) / aLength;
    double bBody = MathAbs(Open[b] - Close[b]) / bLength;
    total += calculateSimilarity(aBody, bBody);

    // % diff from prev High
    double aPrevLength = High[a + 1] - Low[a + 1];
    aPrevLength = aPrevLength == 0 ? 0.00001 : aPrevLength;
    double bPrevLength = High[b + 1] - Low[b + 1];
    bPrevLength = bPrevLength == 0 ? 0.00001 : bPrevLength;
    double aDiffInHigh = (High[a] - High[a + 1]) / aPrevLength;
    double bDiffInHigh = (High[b] - High[b + 1]) / bPrevLength;
    total += (aDiffInHigh > 0 && bDiffInHigh < 0) || (aDiffInHigh < 0 && bDiffInHigh > 0) ? 0 : calculateSimilarity(MathAbs(aDiffInHigh), MathAbs(bDiffInHigh));

    // % diff from prev Low
    double aDiffInLow = (Low[a] - Low[a + 1]) / aPrevLength;
    double bDiffInLow = (Low[b] - Low[b + 1]) / bPrevLength;
    total += (aDiffInLow > 0 && bDiffInLow < 0) || (aDiffInLow < 0 && bDiffInLow > 0) ? 0 : calculateSimilarity(MathAbs(aDiffInLow), MathAbs(bDiffInLow));

    // Future ideas:
    // atr
    // stochastics
    // macd
    // ma
    // other indicators

    return total / 7; // average
}

int calculateSimilarity(double a, double b) {
    double larger  = a > b ? a : b;
    double smaller = a > b ? b : a;
    return (int) ((1 - (larger - smaller)) * 100);
}

double predictDiffInHighest(int pastBar, int predictionBars = 4) {
    int highest = iHighest(Symbol(), 0, MODE_HIGH, predictionBars, pastBar - (predictionBars - 1));
    return High[highest] - High[pastBar + 1];
}

double predictDiffInLowest(int pastBar, int predictionBars = 4) {
    int lowest = iLowest(Symbol(), 0, MODE_LOW, predictionBars, pastBar - (predictionBars - 1));
    return Low[lowest] - Low[pastBar + 1];
}
