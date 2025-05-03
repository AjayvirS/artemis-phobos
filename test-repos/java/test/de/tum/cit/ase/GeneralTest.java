package de.tum.cit.ase;

import de.tum.in.test.api.jupiter.Public;
import de.tum.in.test.api.jupiter.PublicTest;
import de.tum.in.test.api.structural.MethodTestProvider;
import de.tum.in.test.api.util.ReflectionTestUtils;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.fail;

@H01E04
@Public
class GeneralTest extends MethodTestProvider {

    double epsilon = 0.000001d;

    @PublicTest
    @DisplayName("PumpkinConstructorTest")
    public void pumpkinConstructorTest() {
        double weight = 2.3;
        String[] paramNames = {"weight"};
        HelperMethods.testConstructor("Pumpkin", paramNames, false, weight);
    }

    @PublicTest
    @DisplayName("PumpkinInitializeVariablesTest")
    public void pumpkinInitializeVariablesTest() {
        double weight = 3.06;
        String[] paramNames = {"Weight"};
        HelperMethods.testConstructor("Pumpkin", paramNames, true, weight);
    }
    /*
    @Test
    @DisplayName("PumpkinSetterTest")
    public void pumpkinSetterTest() {
        double weight = 3.06;
        java.lang.String type = "Buttercup";
        String[] paramNames = {"Type", "Weight"};
        testSetter("Pumpkin", paramNames, new Object[] {"initialName", 0.0}, type, weight);
    }*/

    @PublicTest
    @DisplayName("GhostConstructorTest")
    public void ghostConstructorTest() {
        String temper = "happy";
        int age = 33;
        double weight = 10.00;
        String[] paramNames = {"temper", "age"};
        HelperMethods.testConstructor("Ghost", paramNames, false, temper, age, weight);
    }

    @PublicTest
    @DisplayName("GhostInitializeVariablesTest")
    public void ghostInitializeVariablesTest() {
        String temper = "angry";
        int age = 102;
        double weight = 10.00;
        String[] paramNames = {"temper", "age", "weight"};
        HelperMethods.testConstructor("Ghost", paramNames, false, temper, age, weight);
    }

    /*
    @Test
    @DisplayName("GhostSetterTest")
    public void GhostSetterTest() {
        String temper = "happy";
        int age = 33;
        String[] paramNames = {"Temper", "Age"};
        testSetter("Ghost", paramNames, new Object[] {"neutral", 0}, temper, age);
    }*/

    @PublicTest
    @DisplayName("CandleConstructorTest")
    public void candleConstructorTest() {
        double radius = 2.0;
        double height = 3f;
        String[] paramNames = {"radius", "height"};
        HelperMethods.testConstructor("Candle", paramNames, false, radius, height);
    }

    @PublicTest
    @DisplayName("CandleInitializeVariablesTest")
    public void candleInitializeVariablesTest() {
        double radius = 1.7;
        double height = 2.4f;
        String[] paramNames = {"Radius", "Height"};
        HelperMethods.testConstructor("Candle", paramNames, true, radius, height);
    }

    /*
        @Test
        @DisplayName("CandleSetterTest")
        public void CandleSetterTest() {
            double radius = 1.0;
            double height = 3.1f;
            String[] paramNames = {"Radius", "Height"};
            testSetter("Candle", paramNames, new Object[]{0.0, 0.0f}, radius, height);
        }
    */

    @PublicTest
    @DisplayName("CarveFaceTest")
    public void carveFaceTest() {
        double weight = 4.2;
        Object pumpkin = HelperMethods.getInstance("Pumpkin", weight);
        ReflectionTestUtils.invokeMethod(pumpkin, "carveFace", "sad");
        Object face = ReflectionTestUtils.invokeMethod(pumpkin, "getFace");
        if (!(face instanceof String)) {
            fail("The method getFace() does not return a String");
        }
        if (!((String) face).equals("sad")) {
            fail("The method carveFace() does not set the face correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("LightTest")
    public void lightTest() {
        double radius = 1.0;
        double height = 3.1f;
        Object candle = HelperMethods.getInstance("Candle", radius, height);
        Object isBurning = ReflectionTestUtils.invokeMethod(candle, "isBurning");
        if (!(isBurning instanceof Boolean)) {
            fail("The method isBurning() does not return a boolean.");
        }
        if ((boolean) isBurning) {
            fail("isBurning() returned true even though the candle was not lit yet.");
        }
        ReflectionTestUtils.invokeMethod(candle, "light");
        isBurning = ReflectionTestUtils.invokeMethod(candle, "isBurning");
        if (!(isBurning instanceof Boolean)) {
            fail("The method isBurning() does not return a boolean.");
        }
        if (!((boolean) isBurning)) {
            fail("isBurning() returned false even though the candle was lit. Check whether light and isBurning are implemented correctly.");
        }
    }

    @PublicTest
    @DisplayName("JackOLanternConstructorTest")
    public void jackOLanternConstructorTest() {
        double radius = 2.0;
        double height = 1.3f;
        double ghostWeight = 10.0;
        double pumpkinWeight = 7.3;
        String temper = "bloodthirsty";
        int age = 57;
        Object ghost = HelperMethods.getInstance("Ghost", temper, age, ghostWeight);
        Object candle = HelperMethods.getInstance("Candle", radius, height);
        Object pumpkin = HelperMethods.getInstance("Pumpkin", pumpkinWeight);

        String[] paramNames = {"pumpkin", "candle", "ghost"};
        HelperMethods.testConstructor("JackOLantern", paramNames, false, pumpkin, candle, ghost);
    }

    @PublicTest
    @DisplayName("JackOLanternGetterTest")
    public void jackOLanternGetterTest() {
        double radius = 2.3;
        double height = 0.9f;
        double ghostWeight = 10.0;
        double pumpkinWeight = 5.3;
        String temper = "melancholic";
        int age = 312;
        Object ghost = HelperMethods.getInstance("Ghost", temper, age, ghostWeight);
        Object candle = HelperMethods.getInstance("Candle", radius, height);
        Object pumpkin = HelperMethods.getInstance("Pumpkin", pumpkinWeight);

        String[] paramNames = {"Pumpkin", "Candle", "Ghost"};
        HelperMethods.testConstructor("JackOLantern", paramNames, true, pumpkin, candle, ghost);
    }

    @PublicTest
    @DisplayName("GhostWeightTest")
    public void ghostWeightTest() {
        double ghostWeight = 10.0;

        Object ghost = HelperMethods.getInstance("Ghost", "happy", 75, ghostWeight);
        Object weight = ReflectionTestUtils.invokeMethod(ghost, "calculateWeight");
        if (!(weight instanceof Double)) {
            fail("The method calculateWeight() does not return a double.");
        }
        if ((double) weight != 10.0) {
            fail("The weight was not calculated correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("CandleWeightTest")
    public void candleWeightTest() {
        double radius = 2.0;
        double height = 1.3f;
        Object candle = HelperMethods.getInstance("Candle", radius, height);
        Object weight = ReflectionTestUtils.invokeMethod(candle, "calculateWeight");
        if (!(weight instanceof Double)) {
            fail("The method calculateWeight() does not return a double.");
        }
        if ((Math.abs((double) weight) - 15.5116) > epsilon) {
            fail("The weight of the candle was not calculated correctly. Make sure you follow the formula given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("PumpkinWeightTest")
    public void pumpkinWeightTest() {
        double pumpkinWeight = 7.3;
        Object pumpkin = HelperMethods.getInstance("Pumpkin", pumpkinWeight);
        ReflectionTestUtils.invokeMethod(pumpkin, "calculateWeight");
        Object weight = ReflectionTestUtils.invokeMethod(pumpkin, "getWeight");
        if (!(weight instanceof Double)) {
            fail("getWeight does not return a double.");
        }

        if (Math.abs(((double) weight) - (pumpkinWeight * 0.3)) > epsilon) {
            fail("The weight of the pumpkin was not calculated correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("CombinedWeightTest")
    public void combinedWeightTest() {
        double radius = 2.0;
        double height = 5.0;
        double weightPumpkin = 10.0;
        double ghostWeight = 10.0;

        double actualWeight = (0.3 * weightPumpkin) + (3.14 * radius * radius * height * 0.95) + ghostWeight;

        Object pumpkin = HelperMethods.getInstance("Pumpkin", weightPumpkin);
        Object candle = HelperMethods.getInstance("Candle", radius, height);
        Object ghost = HelperMethods.getInstance("Ghost", "happy", 75, ghostWeight);
        Object jack = HelperMethods.getInstance("JackOLantern", pumpkin, candle, ghost);

        Object weight = ReflectionTestUtils.invokeMethod(jack, "calculateLanternWeight");

        if (!(weight instanceof Double)) {
            System.out.println("calculateWeight does not return a double");
        }

        if (Math.abs((double) weight - actualWeight) > epsilon) {
            fail("The weight of the lantern was not calculated correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("pumpkinWeightTestHidden")
    public void pumpkinWeightBeforeAndAfterTest() {

        double pumpkinWeight = 16.89;

        Object pumpkin = HelperMethods.getInstance("Pumpkin", pumpkinWeight);

        Object weight = ReflectionTestUtils.invokeMethod(pumpkin, "getWeight");

        if (!(weight instanceof Double)) {
            fail("getWeight does not return a double.");
        }

        if (Math.abs((double) weight - (pumpkinWeight)) > epsilon) {
            fail("The weight of the pumpkin was not set correctly in the constructor.");
        }

        ReflectionTestUtils.invokeMethod(pumpkin, "calculateWeight");

        weight = ReflectionTestUtils.invokeMethod(pumpkin, "getWeight");

        if (!(weight instanceof Double)) {
            fail("getWeight does not return a double.");
        }

        if (Math.abs((double) weight - (pumpkinWeight * 0.3)) > epsilon) {
            fail("The weight of the pumpkin was not calculated correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("GhostScarePower")
    public void ghostScarePower() {
        double ghostWeight = 10.0;

        double expectedScarePower = 750.0;

        Object ghost = HelperMethods.getInstance("Ghost", "happy", 75, ghostWeight);
        Object scarePower = ReflectionTestUtils.invokeMethod(ghost, "scarePower");
        if (!(scarePower instanceof Double)) {
            fail("The method calculateWeight() does not return a double.");
        }
        if ((double) scarePower != expectedScarePower) {
            fail("The weight of the ghost was not calculated correctly. Make sure you follow the instructions given in the problem " +
                    "statement.");
        }
    }

    @PublicTest
    @DisplayName("CarveFaceTestHidden")
    public void carveFaceAndIsSeedPumpkinTest() {
        double weight = 4.2;
        Object pumpkin = HelperMethods.getInstance("Pumpkin", weight);
        Object hasSeeds = ReflectionTestUtils.invokeMethod(pumpkin, "isSeeds");
        if (!(hasSeeds instanceof Boolean)) {
            fail("The method isSeeds() does not return a boolean.");
        }
        if (!((boolean) hasSeeds)) {
            fail("isSeeds() returned false even though carveFace() was not called yet.");
        }
        ReflectionTestUtils.invokeMethod(pumpkin, "carveFace", "sad");
        hasSeeds = ReflectionTestUtils.invokeMethod(pumpkin, "isSeeds");
        if (!(hasSeeds instanceof Boolean)) {
            fail("The method isSeeds() does not return a boolean");
        }
        if ((boolean) hasSeeds) {
            fail("isSeeds() returned true even though carveFace() was already called.");
        }
    }

    @PublicTest
    @DisplayName("candleBurningTest")
    public void candleBurningBeforeAndAfterTest() {
        double radius = 2.0;
        double height = 3f;


        Object candle = HelperMethods.getInstance("Candle", radius, height);

        Object burning = ReflectionTestUtils.invokeMethod(candle, "isBurning");

        if (burning == null) {
            fail("value for burning is not set when the object is created");
        }

        if ((boolean) burning) {
            fail("The candle should not be burning by default, but it is");
        }


        ReflectionTestUtils.invokeMethod(candle, "light");
        burning = ReflectionTestUtils.invokeMethod(candle, "isBurning");

        if (!(boolean) burning) {
            fail("The candle is not burning but it should be after calling the method light()");
        }
    }


    @PublicTest
    @DisplayName("hiddenCandleWeightTest")
    public void hiddenCandleWeightTest() {
        double height = 5.5f;
        double radius = 2.0;


        Object candle = HelperMethods.getInstance("Candle", radius, height);

        Object weight = ReflectionTestUtils.invokeMethod(candle, "calculateWeight");

        if (!(weight instanceof Double)) {
            fail("calculateWeight does not return a double.");
        }

        double actualWeight = 3.14 * radius * radius * height * 0.95;

        if (Math.abs((double) weight - actualWeight) > epsilon) {
            fail("The weight of the candle was not calculated correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("JackOLanternWeightTest")
    public void JackOLanternWeightTest() {
        double radius = 15;
        double height = 4.99f;
        double weightPumpkin = 5.78;
        double weightGhost = 10.0;

        double actualWeight = (0.3 * weightPumpkin) + (3.14 * radius * radius * height * 0.95) + weightGhost;

        Object pumpkin = HelperMethods.getInstance("Pumpkin", weightPumpkin);
        Object candle = HelperMethods.getInstance("Candle", radius, height);
        Object ghost = HelperMethods.getInstance("Ghost", "happy", 75, weightGhost);
        Object jack = HelperMethods.getInstance("JackOLantern", pumpkin, candle, ghost);

        Object weight = ReflectionTestUtils.invokeMethod(jack, "calculateLanternWeight");

        if (!(weight instanceof Double)) {
            System.out.println("calculateWeight does not return a double");
        }

        if (Math.abs((double) weight - actualWeight) > epsilon) {
            fail("The weight of the lantern was not calculated correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("CarvingTest")
    public void faceBeforeCarvingTest() {

        double pumpkinWeight = 16.89;

        Object pumpkin = HelperMethods.getInstance("Pumpkin", pumpkinWeight);

        Object face = ReflectionTestUtils.invokeMethod(pumpkin, "getFace");

        if (face == null) {
            fail("the attribute face has not been initialised");
        }

        if (!(face instanceof String)) {
            fail("getFace does not return a String.");
        }

        if (!face.equals("")) {
            fail("The constructor does not set the face to an empty string.");
        }
    }

    @PublicTest
    @DisplayName("HauntedLanternTest")
    public void hauntedLanternTest() {
        double radius = 1.0;
        double height = 3.1f;
        Object candle = HelperMethods.getInstance("Candle", radius, height);

        ReflectionTestUtils.invokeMethod(candle, "light");
        Object isBurning = ReflectionTestUtils.invokeMethod(candle, "isBurning");
        if (!(isBurning instanceof Boolean)) {
            fail("The method isBurning() does not return a boolean.");
        }
        if (!((boolean) isBurning)) {
            fail("isBurning() returned false even though the candle was lit. Check whether the method hauntedLantern() is implemented correctly or that the methods light() and isBurning()" +
                    "are implemented correctly.");
        }

        double weight = 4.2;
        Object pumpkin = HelperMethods.getInstance("Pumpkin", weight);

        double ghostWeight = 10.0;

        double expectedScarePower = 750.0;

        Object ghost = HelperMethods.getInstance("Ghost", "happy", 75, ghostWeight);

        Object jack = HelperMethods.getInstance("JackOLantern", pumpkin, candle, ghost);
        Object scarePower = ReflectionTestUtils.invokeMethod(jack, "hauntedLantern");
        if (!(scarePower instanceof Double)) {
            fail("The method calculateWeight() does not return a double.");
        }
        if ((double) scarePower != expectedScarePower) {
            fail("The weight was not calculated correctly. Make sure you follow the instructions given in the problem " +
                    "statement.");
        }
    }

    @PublicTest
    @DisplayName("GhostMaxWeightTest")
    public void ghostMaxWeightTest() {
        double ghostWeight = 10.0;

        Object ghost = HelperMethods.getInstance("Ghost", "happy", 75, ghostWeight);
        Object weight = ReflectionTestUtils.invokeMethod(ghost, "calculateMaxWeight");
        if (!(weight instanceof Double)) {
            fail("The method calculateWeight() does not return a double.");
        }
        if ((double) weight != 20.0) {
            fail("The maxWeight was not calculated correctly. Make sure you follow the instructions given in the problem " +
                    "statement.");
        }
    }

    @PublicTest
    @DisplayName("CandleMaxWeightTest")
    public void candleMaxWeightTest() {
        double radius = 2.0;
        double height = 1.3f;

        double maxRadius = 2.0;
        double maxHeight = 10.0;

        Object candle = HelperMethods.getInstance("Candle", radius, height);
        Object weight = ReflectionTestUtils.invokeMethod(candle, "calculateMaxWeight");
        if (!(weight instanceof Double)) {
            fail("The method calculateWeight() does not return a double.");
        }
        if ((Math.abs((double) weight) - (3.14 * maxRadius * maxRadius * maxHeight * 0.95)) > epsilon) {
            fail("The maxWeight was not calculated correctly. Make sure you follow the formula given in the problem " +
                    "statement.");
        }
    }

    @PublicTest
    @DisplayName("PumpkinMaxWeightTest")
    public void pumpkinMaxWeightTest() {
        double pumpkinMaxWeight = 20.00;
        Object pumpkin = HelperMethods.getInstance("Pumpkin", pumpkinMaxWeight);
        Object weight = ReflectionTestUtils.invokeMethod(pumpkin, "calculateMaxWeight");
        if (!(weight instanceof Double)) {
            fail("getWeight does not return a double.");
        }

        if (Math.abs(((double) weight) - (pumpkinMaxWeight * 0.3)) > epsilon) {
            fail("The weight of the pumpkin was not calculated correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }

    @PublicTest
    @DisplayName("CombinedMaxWeightTest")
    public void combinedMaxWeightTest() {
        double radius = 2.0;
        double height = 10.0;
        double weightPumpkin = 20.00;
        double ghostWeight = 20.00;

        double actualWeight = (0.3 * weightPumpkin) + (3.14 * radius * radius * height * 0.95) + ghostWeight;

        Object pumpkin = HelperMethods.getInstance("Pumpkin", weightPumpkin);
        Object candle = HelperMethods.getInstance("Candle", radius, height);
        Object ghost = HelperMethods.getInstance("Ghost", "happy", 75, ghostWeight);
        Object jack = HelperMethods.getInstance("JackOLantern", pumpkin, candle, ghost);

        Object weight = ReflectionTestUtils.invokeMethod(jack, "calculateMaxLanternWeight");

        if (!(weight instanceof Double)) {
            System.out.println("calculateWeight does not return a double");
        }

        if (Math.abs((double) weight - actualWeight) > epsilon) {
            fail("The weight of the lantern was not calculated correctly. Make sure you follow the instructions given in the problem statement.");
        }
    }
}
