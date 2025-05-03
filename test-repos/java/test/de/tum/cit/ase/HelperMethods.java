package de.tum.cit.ase;

import de.tum.in.test.api.util.ReflectionTestUtils;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;

import static org.junit.jupiter.api.Assertions.fail;

public class HelperMethods {
    public static void testConstructor(String className, String[] paramNames, boolean withGetter, Object... args) {
        Object newInstance = getInstance(className, args);
        if (withGetter) {
            Object[] returnValues = testGetter(newInstance, paramNames, args);
            if (!Arrays.equals(args, returnValues)) {
                fail("The variables of "+className+ " can not be accessed. Make sure you initialize them in the constructor" +
                        " and implement the getters for them.");
            }
        } else {
	        for (int i = 0; i < paramNames.length; i++) {
		        String param = paramNames[i];
		        Object value = ReflectionTestUtils.valueForNonPublicAttribute(newInstance, param);
		        if (!Objects.equals(value, args[i])) {
					fail("Your constructor of " + className + " does not initialize the attributes correctly");
		        }
	        }
        }
    }

    public static Object[] testGetter(Object instance, String[] paramNames, Object... args) {
        Object[] returnValues = new Object[paramNames.length];

        for (int i = 0; i < paramNames.length; i++) {
            String getter;
            if (args[i] instanceof Boolean) {
                getter = "is"+paramNames[i];
            } else {
                getter = "get"+paramNames[i];
            }
            returnValues[i] = ReflectionTestUtils.invokeMethod(instance, getter);
        }

        return returnValues;
    }

    public static void testSetter(String className, String[] paramNames, Object[] initialValues, Object... args) {
        Object instance = getInstance(className, initialValues);
        for (int i = 0; i < paramNames.length; i++) {
            String setter = "set"+paramNames[i];
            Class<?> c;
            if (args[i] instanceof Double) {
                c = double.class;
            } else if (args[i] instanceof Integer) {
                c = int.class;
            } else {
                c = args[i].getClass();
            }
            Method m = ReflectionTestUtils.getMethod(instance, setter, c);
            ReflectionTestUtils.invokeMethod(instance, m, args[i]);
        }

        Object[] returnValues = testGetter(instance, paramNames, args);
        for (int i = 0; i<args.length; i++) {
            if (!returnValues[i].equals(args[i])) {
                fail("The variable "+paramNames[i]+ " is not set correctly. Make sure you implemented the setter and " +
                        "getter for it.");
            }
        }
    }

    public static Constructor<?> getConstructor(String classString, Class<?>[] parameterTypes) {
        List<Constructor<?>> classList = Arrays.stream(ReflectionTestUtils.getClazz(classString).getConstructors())
                .filter(constructor -> Arrays.equals(constructor.getParameterTypes(), parameterTypes))
                .toList();
        if (classList.isEmpty()) {
            fail("The " + classString + " class has no constructor with the parameter types: " + Arrays.toString(parameterTypes));
            return null;
        } else if (classList.size() >= 2){
            fail("The " + classString + " class has more than one constructor with the parameter types: " + Arrays.toString(parameterTypes));
            return null;
        } else {
            return classList.get(0);
        }
    }

    public static Object getInstance(String className, Object... args) {
        Class<?>[] classList = new Class<?>[args.length];
        for (int i = 0; i<args.length; i++) {
            if (args[i] instanceof Integer) {
                classList[i] = int.class;
            } else if (args[i] instanceof Double) {
                classList[i] = double.class;
            } else if (args[i] instanceof  Double) {
                classList[i] = double.class;
            } else {
                classList[i] = args[i].getClass();
            }
        }
        return ReflectionTestUtils.newInstance(
                Objects.requireNonNull(getConstructor(
                        "de.tum.cit.ase."+className,
                        classList
                )), args
        );
    }
}
