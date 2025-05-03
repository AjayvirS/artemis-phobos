package de.tum.cit.ase;

public class Candle {
    private double radius;
    private double height;
    private boolean burning;
    private static double maxHeight = 10.0;
    private static double maxRadius = 2.0;

    //constructor
    public Candle(double radius, double height) {
        this.radius = radius;
        this.height = height;
        this.burning = false;
    }

    //getters and setters
    public double getRadius() {
        return radius;
    }

    public void setRadius(double radius) {
        this.radius = radius;
    }

    public double getHeight() {
        return height;
    }

    public void setHeight(double height) {
        this.height = height;
    }

    public boolean isBurning() {
        return burning;
    }

    public void setBurning(boolean burning) {
        this.burning = burning;
    }

    public static double getMaxHeight() {
        return maxHeight;
    }

    public static void setMaxHeight(double maxHeight) {
        Candle.maxHeight = maxHeight;
    }

    public static double getMaxRadius() {
        return maxRadius;
    }

    public static void setMaxRadius(double maxRadius) {
        Candle.maxRadius = maxRadius;
    }



    //method of light
    public void light(){
        this.burning = true;
    }

    //method of calculateWeight
    public double calculateWeight(){
        double pi = 3.14;
        return pi * radius * radius * height * 0.95;
    }

    //method of calculateMaxWeight
    public static double calculateMaxWeight(){
        double pi = 3.14;
        return pi * maxRadius * maxRadius * maxHeight * 0.95;
    }
}
