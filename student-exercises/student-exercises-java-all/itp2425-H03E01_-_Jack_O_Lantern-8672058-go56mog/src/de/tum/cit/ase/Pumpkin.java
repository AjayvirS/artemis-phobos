package de.tum.cit.ase;

public class Pumpkin {
    private double weight;
    private String face;
    private boolean seeds;
    private static double maxWeight = 20.0;

    //constructor
    public Pumpkin(double weight) {
        this.weight = weight;
        this.face = "";
        this.seeds = true;
    }

    //getters and setters
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


    //method of calculateWeight
    public double calculateWeight() {
        this.weight = this.weight - (0.7 * weight);
        return this.weight;
    }


    //method of carveFace(temper: String)
    public void carveFace(String temper) {
        if(seeds){
            seeds = false;
        }
        //Candle.light();


        this.face = temper;

    }

    //method of calculateMaxWeight
    public static double calculateMaxWeight(){
        return maxWeight*0.3;
    }


    }


