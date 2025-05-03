package de.tum.cit.ase;

import de.tum.in.test.api.*;

import java.lang.annotation.Retention;
import java.lang.annotation.Target;

import static java.lang.annotation.ElementType.ANNOTATION_TYPE;
import static java.lang.annotation.ElementType.TYPE;
import static java.lang.annotation.RetentionPolicy.RUNTIME;

@WhitelistClass(HelperMethods.class)
@WhitelistPath(value = "../testprog23h01e04**", type = PathType.GLOB) // for manual assessment and development
@WhitelistPath("target") // mainly for Artemis
//@BlacklistPath(value = "target/test-classes**Test*.{java,class}", type = PathType.GLOB)
@BlacklistPath(value = "{build/classes/java/test,test}/**.{java,class,json}", type = PathType.GLOB)
@MirrorOutput
@StrictTimeout(3)
@Retention(RUNTIME)
@Target({TYPE, ANNOTATION_TYPE})
@Deadline("2023-11-08 19:03 Europe/Berlin")
public @interface H01E04 {
}
