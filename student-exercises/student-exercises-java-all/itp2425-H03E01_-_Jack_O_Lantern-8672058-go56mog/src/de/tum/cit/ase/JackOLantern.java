package de.tum.cit.ase;

import jdk.jfr.FlightRecorder;

public class JackOLantern {
    private static Ghost ghostOfHalloween;
    private Pumpkin pumpkin;
    private Candle candle;
    private Ghost ghost;

    // In order to create a jack o'lantern the weight of the pumpkin needs to be calculated and carved.

    //constructor
    public JackOLantern(Pumpkin pumpkin, Candle candle, Ghost ghost) {
        this.pumpkin = pumpkin;
        this.candle = candle;
        this.ghost = ghost;


    }


    //getters and setter
    public Ghost getGhostOfHalloween() {
        return ghostOfHalloween;
    }

    public Pumpkin getPumpkin() {
        return pumpkin;
    }

    public Candle getCandle() {
        return candle;
    }

    public Ghost getGhost() {
        return ghost;
    }

    public void setCandle(Candle candle) {
        this.candle = candle;
    }

    public void setGhostOfHalloween(Ghost ghostOfHalloween) {
        this.ghostOfHalloween = ghostOfHalloween;
    }

    public void setPumpkin(Pumpkin pumpkin) {
        this.pumpkin = pumpkin;
    }

    public void setGhost(Ghost ghost) {
        this.ghost = ghost;
    }





    //method of calculateLanternWeight
    public double calculateLanternWeight() {
        return pumpkin.calculateWeight() + candle.calculateWeight() + ghost.calculateWeight();
    }

    //method of calculateMaxLanternWeight
    public static double calculateMaxLanternWeight(){
        double pi = 3.14;
        return (pi * Candle.getMaxRadius() * Candle.getMaxRadius() * Candle.getMaxHeight() * 0.95) + Ghost.calculateMaxWeight() + Pumpkin.calculateMaxWeight();

    }

    //method of hauntedLantern
    public double hauntedLantern(){
        candle.light();
        return ghost.scarePower();
    }


}
