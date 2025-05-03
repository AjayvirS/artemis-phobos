package de.tum.cit.ase;

public class JackOLantern {
    private static Ghost ghostOfHalloween;
    private Ghost ghost;
    private Pumpkin pumpkin;
    private Candle candle;

    // constructor
    public JackOLantern(Pumpkin pumpkin, Candle candle, Ghost ghost) {
        this.pumpkin = pumpkin;
        this.candle = candle;
        this.ghost = ghost;
    }

    // getters & setters
    public Ghost getGhost() {
        return ghost;
    }

    public void setGhost(Ghost ghost) {
        this.ghost = ghost;
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

    // methods
    public double calculateLanternWeight() {
        return pumpkin.calculateWeight() + candle.calculateWeight() + ghost.calculateWeight();
    }

    public static double calculateMaxLanternWeight() {
        return Pumpkin.calculateMaxWeight() + Candle.calculateMaxWeight() + Ghost.calculateMaxWeight();
    }

    public double hauntedLantern() {
        candle.light();
        return ghost.scarePower();
    }
}
