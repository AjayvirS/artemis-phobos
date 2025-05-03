package de.tum.cit.ase;

public class Pumpkin {
    private double weight;
    private String face;
    private boolean seeds;
    private static double maxWeight = 20.0;

    // constructor

    public Pumpkin(double weight) {
        this.weight = weight;
        this.face = "";
        this.seeds = true;
    }

    // getters & setters

    public double getWeight() {
        return weight;
    }

    public void setWeight(double weight) {
        this.weight = weight;
    }

    public String getFace() {
        return face;
    }

    public void setFace(String face) {
        this.face = face;
    }

    public boolean isSeeds() {
        return seeds;
    }

    public void setSeeds(boolean seeds) {
        this.seeds = seeds;
    }

    public static double getMaxWeight() {
        return maxWeight;
    }

    public static void setMaxWeight(double maxWeight) {
        Pumpkin.maxWeight = maxWeight;
    }

    // methods

    public double calculateWeight() {
        return weight = 0.3 * weight;
    }

    public void carveFace(String face) {
        this.face = face;
        this.seeds = false;
    }

    public static double calculateMaxWeight() {
        return 0.3 * Pumpkin.maxWeight;
    }
}
