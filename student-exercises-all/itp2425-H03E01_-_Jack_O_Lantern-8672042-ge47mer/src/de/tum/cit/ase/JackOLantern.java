package de.tum.cit.ase;

public class JackOLantern {
    private Pumpkin pumpkin;
    private Candle candle;
    private static Ghost ghostOfHalloween;
    private Ghost ghost;

    public JackOLantern(Pumpkin pumpkin, Candle candle, Ghost ghost) {
        this.pumpkin = pumpkin;
        this.candle = candle;
        this.ghostOfHalloween = ghost;
        this.ghost = ghost;
        this.pumpkin.calculateWeight();
        this.pumpkin.carveFace(ghost.getTemper());
    }
    public double calculateLanternWeight(){
        return pumpkin.getWeight() + candle.calculateWeight() +ghostOfHalloween.calculateWeight();
    }

    public static double calculateMaxLanternWeight() {
        return Pumpkin.getMaxWeight() + Candle.calculateMaxWeight() + Ghost.calculateMaxWeight();
    }
    public double hauntedLantern(){
        candle.light();
        return ghostOfHalloween.scarePower();
    }

    public Ghost getGhost() {
        return ghostOfHalloween;
    }

    public void setGhost(Ghost ghostOfHalloween) {
        this.ghostOfHalloween = ghostOfHalloween;
    }

    public Candle getCandle() {
        return candle;
    }

    public void setCandle(Candle candle) {
        this.candle = candle;
    }

    public Pumpkin getPumpkin() {
        return pumpkin;
    }

    public void setPumpkin(Pumpkin pumpkin) {
        this.pumpkin = pumpkin;
    }
}
