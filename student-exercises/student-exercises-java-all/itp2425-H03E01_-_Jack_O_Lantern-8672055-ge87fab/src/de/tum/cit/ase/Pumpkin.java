package de.tum.cit.ase;

public class Pumpkin {
    private static double maxWeight = 20.0;

    private double weight;

    private String face;

    private boolean seeds;

    public Pumpkin (double weight){
        this.weight = weight;
        this.face ="";
        this.seeds = true;
    }



    public boolean isSeeds() {
        return seeds;
    }

    public double getWeight() {
        return weight;
    }

    public String getFace() {
        return face;
    }

    public void setFace(String face) {
        this.face = face;
    }

    public void setSeeds(boolean seeds) {
        this.seeds = seeds;
    }

    public void setWeight(double weight) {
        this.weight = weight;
    }
    public void carveFace(String temper){
        this.seeds = false;
        this.face = temper;
    }
    public double calculateWeight(){
        weight = weight*0.3;
        return weight;
    }
    public static double calculateMaxWeight(){
        return maxWeight*0.3;
    }
}
