package de.tum.cit.ase;

public class Pumpkin {

    private double weight;
    private String face;
    private boolean seeds;
    private static double maxWeight = 20.0;

    public Pumpkin(double weight) {
        this.weight = weight;
        this.face = "";
        this.seeds = true;
    }

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

    // Implement the method calculateWeight()

    public double calculateWeight() {
        weight = weight * 0.3;
        return weight;
    }

    // Implement the method carveFace

    public void carveFace(String temper) {
        face = temper;
        seeds = false;
    }

    // Static method for maxWeight

    public static double calculateMaxWeight() {
        return maxWeight * 0.3;
    }
}
