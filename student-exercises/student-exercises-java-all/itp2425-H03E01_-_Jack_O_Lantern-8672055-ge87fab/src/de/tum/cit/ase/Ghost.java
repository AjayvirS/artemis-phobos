package de.tum.cit.ase;

public class Ghost {
    private static double maxWeight = 20.0;
    private String temper;
    private int age;
    private double weight;

    public Ghost(String temper, int age, double weight){
        this.temper = temper;
        this.age = age;
        this .weight = weight;
    }

    public void setAge(int age) {
        this.age = age;
    }

    public int getAge() {
        return age;
    }

    public static double getMaxWeight() {
        return maxWeight;
    }

    public double getWeight() {
        return weight;
    }

    public static void setMaxWeight(double maxWeight) {
        Ghost.maxWeight = maxWeight;
    }

    public void setWeight(double weight) {
        this.weight = weight;
    }

    public String getTemper() {
        return temper;
    }

    public void setTemper(String temper) {
        this.temper = temper;
    }
    public double calculateWeight(){
        return weight;
    }
    public double scarePower(){
        return weight * age;
    }
    public static double calculateMaxWeight(){
        return maxWeight;
    }
}
