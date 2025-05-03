package de.tum.cit.ase;

public class Candle {
    private static double maxHeight = 10.0;
    private static double maxRadius = 2.0;

    private double radius;

    private  double height;

    private boolean burning;

    public Candle (double radius, double height){
        this.radius =radius;
        this.height = height;
        this.burning = false;
    }

    public boolean isBurning() {
        return burning;
    }


    public double getHeight() {
        return height;
    }

    public static double getMaxHeigth() {
        return maxHeight;
    }

    public static double getMaxRadius() {
        return maxRadius;
    }

    public double getRadius() {
        return radius;
    }

    public void setBurning(boolean burning) {
        this.burning = burning;
    }

    public void setHeight(double height) {
        this.height = height;
    }

    public static void setMaxHeigth(double maxHeigth) {
        Candle.maxHeight = maxHeigth;
    }

    public static void setMaxRadius(double maxRadius) {
        Candle.maxRadius = maxRadius;
    }

    public void setRadius(double radius) {
        this.radius = radius;
    }
    public void light(){
        this.burning = true;
    }
    public double calculateWeight(){
        return 3.14 * radius * radius * height * 0.95;
    }
    public static double calculateMaxWeight(){
        return 3.14 * maxHeight * maxRadius * maxRadius * 0.95;
    }
}
