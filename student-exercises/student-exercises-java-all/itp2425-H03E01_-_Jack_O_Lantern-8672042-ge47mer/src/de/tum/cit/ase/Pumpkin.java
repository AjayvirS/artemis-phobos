package de.tum.cit.ase;

public class Pumpkin {
    private double weight;
    private String face;
    private boolean seeds;
    private  static  double maxWeight =  20.0;

    public Pumpkin(double weight){
        this.weight = weight;
        this.face = "";
        this.seeds = true;
    }

    public  static double calculateMaxWeight(){
        maxWeight *= 0.3;
        return maxWeight;
    }

    public double calculateWeight(){
        this.weight *= 0.3;
        return this.weight;
    }
    public void carveFace(String temper){
        this.face = temper;
        this.seeds = false;
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
}
