package de.tum.cit.ase;

public class JackOLantern {
    private static Ghost ghostOfHalloween;
    private   Pumpkin pumpkin;
    private   Ghost ghost;
    private   Candle candle;

    public JackOLantern (Pumpkin pumpkin,Candle candle, Ghost ghost){
        this.pumpkin = pumpkin;
        this.candle =candle;
        this.ghost =ghost;
        pumpkin.carveFace(ghost.getTemper());
        pumpkin.getWeight();
    }
    public double calculateLanternWeight(){
        return pumpkin.getWeight()*0.3 + candle.calculateWeight() + ghost.getWeight();
    }
    public double hauntedLantern(){
        candle.setBurning(true);
        return ghost.scarePower();
    }
    public static double calculateMaxLanternWeight(){
        return Pumpkin.calculateMaxWeight() + Candle.calculateMaxWeight() + Ghost.calculateMaxWeight();
    }
    public Pumpkin getPumpkin(){
        return pumpkin;
    }
    public Candle getCandle(){
        return candle;
    }

    public Ghost getGhost() {
        return ghost;
    }

    public void setCandle(Candle candle) {
        this.candle = candle;
    }

    public void setPumpkin(Pumpkin pumpkin) {
        this.pumpkin = pumpkin;
    }

    public void setGhost(Ghost ghost) {
        this.ghost = ghost;
    }
}
