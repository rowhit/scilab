// ======================================================================
// Scilab ( http://www.scilab.org/ ) - This file is part of Scilab
// Copyright (C) 2013 - Scilab Enterprises - Simon MARCHETTO
//
//  This file is distributed under the same license as the Scilab package.
// =======================================================================

// Save original env
origDir = pwd();
verbose = ilib_verbose();

testRootDir = fullfile(TMPDIR, "ilib_build_jar");
mkdir(testRootDir);
cd(testRootDir);

ilib_verbose(0);

// Creates a sub directory of a parent dir, cleans it if exist
function path = createSubDir(parentDir, subDir, removeExistingDir)
    path = fullfile(parentDir, subDir);
    if isdir(path) & removeExistingDir then
        removedir(path);
    end
    mkdir(path);
endfunction

// Create a Java class source code for a specified package, eventually containing an import directive
function sourceCode = createSourceCode(className, packageName, importPackageName)
    sourceCode = msprintf('package %s;\n', packageName);
    if ~isempty(importPackageName) then
        sourceCode = [sourceCode; msprintf('import %s.*;\n', importPackageName)]
    end
    sourceCode = [sourceCode; msprintf('public class %s {}\n', className)];
endfunction

// Adds a Java class source file in a specified package source tree
function filePath = addSourceToPackage(className, packageName, packageSrcPath, sourceCode)
    if ~isempty(packageName) then
        packagePath = strsubst(packageName, '.', filesep());
        path = createSubDir(packageSrcPath, packagePath, %F);
    else
        path = packageSrcPath;
    end

    filePath = fullfile(path, className + '.java');

    fd = mopen(filePath, 'wt');
    if isempty(sourceCode) then
        sourceCode = createSourceCode(className, packageName, '');
    end
    mputl(sourceCode, fd);
    mclose(fd);
endfunction

// Checks the import of a specified class
function checkImportClass(expectedClassName)
    classobj = jimport(expectedClassName, %f);
    aclass = classobj.class;
    className = aclass.getName(jvoid);
    assert_checkequal(className, expectedClassName);
endfunction

// Checks the specified JAR package contains the expected classes (with an import)
function checkJar(jarFilePath, packageNames, expectedClassNames)
    javaclasspath(jarFilePath);
    for i = 1:size(packageNames, 'r')
        for j = 1:size(expectedClassNames, 'c')
            checkImportClass(packageNames(i, 1) + '.' + expectedClassNames(i, j));
        end
    end
endfunction

// Checks the specified JAR build command provokes an error
function checkCompileError(buildJarCmd)
    compileError = msprintf(_('jcompile: An error occured: Cannot compile the code'));
    execstr(buildJarCmd, 'errcatch');
    errMsg = lasterror();
    assert_checktrue(errMsg <> []);
    assert_checktrue(strstr(errMsg, compileError) <> []);
endfunction

// Creates a small JAR containing 1 package and 1 class
function jarFilePath = buildJar1Package1Class(packageName, className, rootPath, sourceCode)
    packageSrcPath = createSubDir(testRootDir, packageName, %T);
    jarFilePath = fullfile(testRootDir, packageName + '.jar');
    addSourceToPackage(className, packageName, packageSrcPath, '');
    ilib_build_jar(jarFilePath, packageName, packageSrcPath);
endfunction

// Chekcs content and execution of loader script loader.sce
function checkLoaderScript(loaderScriptName, jarFilePath, expectedClassName)
    loaderScriptPath = fullpath(loaderScriptName);

    // Check code
    expectedLoaderCode = [ ..
        '// This file is released under the 3-clause BSD license. See COPYING-BSD.'; ..
        '// Generated by builder.sce: Please, do not edit this file.'; ..
        '// ------------------------------------------------------'; ..
        'curdir = pwd();'; ..
        msprintf('scriptdir = get_file_path(''%s'');', loaderScriptName); ..
        'chdir(scriptdir);'; ..
        '// ------------------------------------------------------'; ..
        msprintf('jarFilePath = fullfile(scriptdir, ''%s'');', jarFilePath); ..
        'javaclasspath(fullpath(jarFilePath));'; ..
        '// ------------------------------------------------------'; ..
        'chdir(curdir);'; ..
        'clear curdir;' ..
        ];
    loaderCode = mgetl(loaderScriptPath);
    assert_checkequal(loaderCode, expectedLoaderCode);

    // Check execution result
    res = exec(loaderScriptPath, 'errcatch');
    assert_checkequal(res, 0);
    checkImportClass(expectedClassName);
endfunction

// Checks content and execution of cleaner script cleaner.sce
function checkCleanerScript(cleanerScriptName, loaderScriptName, jarFilePath)
    cleanerScriptPath = fullpath(cleanerScriptName);
    loaderScriptPath = fullpath(loaderScriptName);

    // Check code
    expectedCleanerCode = [ ..
        '// This file is released under the 3-clause BSD license. See COPYING-BSD.'; ..
        '// Generated by builder.sce: Please, do not edit this file.'; ..
        '// ------------------------------------------------------'; ..
        'curdir = pwd();'; ..
        msprintf('scriptdir = get_file_path(''%s'');', cleanerScriptName); ..
        'chdir(scriptdir);'; ..
        '// ------------------------------------------------------'; ..
        msprintf('if fileinfo(''%s'') <> [] then', loaderScriptName); ..
        msprintf('    mdelete(''%s'');', loaderScriptName); ..
        'end'; ..
        '// ------------------------------------------------------'; ..
        msprintf('jarFilePath = fullfile(scriptdir, ''%s'');', jarFilePath); ..
        'if fileinfo(jarFilePath) <> [] then'; ..
        '    mdelete(jarFilePath);'; ..
        'end'; ..
        '// ------------------------------------------------------'; ..
        'chdir(curdir);'; ..
        'clear curdir;' ..
        ];
    cleanerCode = mgetl(cleanerScriptPath);

    assert_checkequal(cleanerCode, expectedCleanerCode);

    // Check execution result
    res = exec(cleanerScriptPath, 'errcatch');
    assert_checkequal(res, 0);
    assert_checkfalse(isfile(loaderScriptPath));
    // A loaded JAR file is locked by the JVM and cannot be deleted (Java 6 issue).
    //assert_checkfalse(isfile(jarFilePath));
endfunction


// TEST JAR BUILD

// Test build a JAR of a simple package with one class
packageName = 'testpackage';
className = 'Foo';
jarFilePath = buildJar1Package1Class(packageName, className, testRootDir, '');
checkJar(jarFilePath, packageName, className);

// Test build a JAR of a package with two classes
packageName = 'testpackage2';
packageSrcPath = createSubDir(testRootDir, packageName, %T);
jarFilePath = fullfile(testRootDir, packageName + '.jar');
addSourceToPackage('Foo1', packageName, packageSrcPath, '');
addSourceToPackage('Foo2', packageName, packageSrcPath, '');
ilib_build_jar(jarFilePath, packageName, packageSrcPath);
checkJar(jarFilePath, packageName, ['Foo1', 'Foo2']);

// Test build a JAR of one 'standard' package
packageName = 'org.scilab.test.mypackage';
packageSrcPath = createSubDir(testRootDir, packageName, %T);
jarFilePath = fullfile(testRootDir, packageName + '.jar');
addSourceToPackage('Foo1', packageName, packageSrcPath, '');
addSourceToPackage('Foo2', packageName + '.folder', packageSrcPath, '');
ilib_build_jar(jarFilePath, packageName, packageSrcPath);
checkJar(jarFilePath, packageName, ['Foo1', 'folder.Foo2']);

// Test build a JAR of two packages
jarFilePath = fullfile(testRootDir, 'testmultipackages.jar');
// package1
packageName1 = 'org.scilab.test.package1';
package1SrcPath = createSubDir(testRootDir, packageName1, %T);
addSourceToPackage('Foo1', packageName1, package1SrcPath, '');
addSourceToPackage('Foo2', packageName1 + '.folder', package1SrcPath, '');
// package2
packageName2 = 'org.scilab.test.package2';
package2SrcPath = createSubDir(testRootDir, packageName2, %T);
addSourceToPackage('FooA', packageName2, package2SrcPath, '');
addSourceToPackage('FooB', packageName2 + '.folder', package2SrcPath, '');
// build
ilib_build_jar(jarFilePath, [packageName1, packageName2], [package1SrcPath, package2SrcPath]);
checkJar(jarFilePath, [packageName1; packageName2], ['Foo1', 'folder.Foo2'; 'FooA', 'folder.FooB']);

// Test compilation errors
packageName = 'testpackagecompileerrors';
packageSrcPath = createSubDir(testRootDir, packageName, %T);
jarFilePath = fullfile(testRootDir, packageName + '.jar');
className = '1234';
sourceCode = createSourceCode(className, packageName, '');
javaFilePath = addSourceToPackage(className, packageName, packageSrcPath);
checkCompileError("ilib_build_jar(jarFilePath, packageName, packageSrcPath)");


// TEST LOADER AND CLEANER SCRIPTS

packageName = 'dummypackage';
className = 'Foo';
jarFilePath = buildJar1Package1Class(packageName, className, testRootDir, '');
checkLoaderScript('loader.sce', 'dummypackage.jar', 'dummypackage.Foo');
checkCleanerScript('cleaner.sce', 'loader.sce', 'dummypackage.jar');


// TEST OPTIONAL ARGUMENTS

// Test dependency packages argument
// create dependency package (in another directory, so that it is not in classpath)
dependencyPackageName = 'dependencypackage';
dependencyJarFilePath = buildJar1Package1Class(dependencyPackageName, 'Dummy', '');
// remove dependency package class directory, because it is in class path
jimsBinPath = fullfile(TMPDIR, 'JIMS/bin');
removedir(fullfile(jimsBinPath, dependencyPackageName));
// create package that uses the dependency
packageName = 'testpackagedependencies';
packageSrcPath = createSubDir(testRootDir, packageName, %T);
jarFilePath = fullfile(testRootDir, packageName + '.jar');
className = 'Bar';
sourceCode = createSourceCode(className, packageName, dependencyPackageName);
// check compile error without specifying dependency
addSourceToPackage(className, packageName, packageSrcPath, sourceCode);
checkCompileError("ilib_build_jar(jarFilePath, packageName, packageSrcPath)");
// check it is ok with specifying dependency
ilib_build_jar(jarFilePath, packageName, packageSrcPath, dependencyJarFilePath);
checkJar(jarFilePath, packageName, className);


// TEST TOOLBOX SKELETON

// Build toolbox skeleton java code and run unit test
toolboxSkeletonSrcPath = fullfile(SCI, "contrib", "toolbox_skeleton");
toolboxSkeletonPath = fullfile(testRootDir, "toolbox_skeleton");
copyfile(toolboxSkeletonSrcPath, toolboxSkeletonPath);
javaBuilderPath = fullfile(toolboxSkeletonPath, "src", "java", "builder_java.sce");
exec(javaBuilderPath);
javaLoaderPath = fullfile(toolboxSkeletonPath, "src", "java", "loader.sce");
exec(javaLoaderPath);
javaTestPath = fullfile(toolboxSkeletonPath, "tests", "unit_tests", "java_sum.tst");
exec(javaTestPath);


// Restore original env
cd(origDir);
ilib_verbose(verbose);