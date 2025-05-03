package de.tum.cit.ase;

public class JackOLantern {
    private Pumpkin pumpkin;
    private Candle candle;
    private Ghost ghost;
    private static Ghost ghostOfHalloween;

    public JackOLantern(Pumpkin pumpkin, Candle candle, Ghost ghostOfHalloween) {
        this.pumpkin = pumpkin;
        this.candle = candle;
        this.ghost = ghostOfHalloween;
    }

    public Pumpkin getPumpkin() {
        return pumpkin;
    }

    public void setPumpkin(Pumpkin pumpkin) {
        this.pumpkin = pumpkin;
    }

    public Candle getCandle() {
        return candle;
    }

    public void setCandle(Candle candle) {
        this.candle = candle;
    }

    public Ghost getGhost() {
        return ghost;
    }

    public void setGhost(Ghost ghost) {
        this.ghost = ghost;
    }

    public static Ghost getGhostOfHalloween() {
        return ghostOfHalloween;
    }

    public static void setGhostOfHalloween(Ghost ghostOfHalloween) {
        JackOLantern.ghostOfHalloween = ghostOfHalloween;
    }

    // Weights Calculated

    public double calculateLanternWeight (){
        return pumpkin.calculateWeight() + candle.calculateWeight() + ghost.calculateWeight();
    }

    public static double calculateMaxLanternWeight(){
        return Pumpkin.calculateMaxWeight() + Candle.calculateMaxWeight() + Ghost.calculateMaxWeight();
    }
    //
    public double hauntedLantern (){
        candle.light();
        return ghost.scarePower();
    }

}
