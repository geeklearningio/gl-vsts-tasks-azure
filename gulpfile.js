// node built-ins
var cp = require('child_process');
var fs = require('fs');
var path = require('path');
var os = require('os');

// build script
var admZip = require('adm-zip');
var minimist = require('minimist');
var mocha = require('gulp-mocha');
var Q = require('q');
var semver = require('semver');
var shell = require('shelljs');
var syncRequest = require('sync-request');
var es = require('event-stream');

// gulp modules
var del = require('del');
var gts = require('gulp-typescript');
var gulp = require('gulp');
var gutil = require('gulp-util');
var pkgm = require('./build-tools/package');
var typescript = require('typescript');
var zip = require('gulp-zip');

var environments = require('./build-tools/environments.json');

// validation
var NPM_MIN_VER = '3.0.0';
var MIN_NODE_VER = '4.0.0';

if (semver.lt(process.versions.node, MIN_NODE_VER)) {
    console.error('requires node >= ' + MIN_NODE_VER + '.  installed: ' + process.versions.node);
    process.exit(1);
}

//
// Paths
//
var _buildRoot = path.join(__dirname, '_build', 'Tasks');
var _testRoot = path.join(__dirname, '_build', 'Tests');
var _testTemp = path.join(_testRoot, 'Temp');
var _pkgRoot = path.join(__dirname, '_package');
var _wkRoot = path.join(__dirname, '_working');
var _tempPath = path.join(__dirname, '_temp');

//-----------------------------------------------------------------------------------------------------------------
// Build Tasks
//-----------------------------------------------------------------------------------------------------------------

function errorHandler(err) {
    process.exit(1);
}

var proj = gts.createProject('./tsconfig.json', { typescript: typescript });
var ts = gts(proj);

gulp.task('clean', function (cb) {
    del([_buildRoot, _pkgRoot, _wkRoot], cb);
});

// compile tasks inline
gulp.task('compileTasks', ['clean'], function (cb) {
    try {
        // Cache all externals in the download directory.
        var allExternalsJson = shell.find(path.join(__dirname, 'Tasks'))
            .filter(function (file) {
                return file.match(/(\/|\\)externals\.json$/);
            })
            .concat(path.join(__dirname, 'build-tools', 'externals.json'));
        allExternalsJson.forEach(function (externalsJson) {
            // Load the externals.json file.
            console.log('Loading ' + externalsJson);
            var externals = require(externalsJson);

            // Check for NPM externals.
            if (externals.npm) {
                // Walk the dictionary.
                var packageNames = Object.keys(externals.npm);
                packageNames.forEach(function (packageName) {
                    // Cache the NPM package.
                    var packageVersion = externals.npm[packageName];
                    cacheNpmPackage(packageName, packageVersion);
                });
            }

            // Check for NuGetV2 externals.
            if (externals.nugetv2) {
                // Walk the dictionary.
                var packageNames = Object.keys(externals.nugetv2);
                packageNames.forEach(function (packageName) {
                    // Cache the NuGet V2 package.
                    var packageVersion = externals.nugetv2[packageName].version;
                    var packageRepository = externals.nugetv2[packageName].repository;
                    cacheNuGetV2Package(packageRepository, packageName, packageVersion);
                })
            }

            // Check for archive files.
            if (externals.archivePackages) {
                // Walk the array.
                externals.archivePackages.forEach(function (archive) {
                    // Cache the archive file.
                    cacheArchiveFile(archive.url);
                });
            }
        });
    }
    catch (err) {
        console.log('error:' + err.message);
        cb(new gutil.PluginError('compileTasks', err.message));
        return;
    }

    var tasksPath = path.join(__dirname, 'Tasks', '**/*.ts');
    return gulp.src([tasksPath, 'definitions/*.d.ts'], { base: './Tasks' })
        .pipe(ts)
        .on('error', errorHandler)
        .pipe(gulp.dest(path.join(__dirname, 'Tasks')));
});

gulp.task('compile', ['compileTasks', 'compileTests']);

gulp.task('locCommon', ['compileTasks'], function () {
    return gulp.src(path.join(__dirname, 'Tasks/Common/**/module.json'))
        .pipe(pkgm.LocCommon());
});

gulp.task('build', ['locCommon'], function () {
    // Load the dependency references to the intra-repo modules.
    var commonDeps = require('./build-tools/common.json');
    var commonSrc = path.join(__dirname, 'Tasks/Common');

    // Layout the tasks.
    shell.mkdir('-p', _buildRoot);
    return gulp.src(path.join(__dirname, 'Tasks', '**/task.json'))
        .pipe(pkgm.PackageTask(_buildRoot, commonDeps, commonSrc));
});

gulp.task('default', ['build']);

var cacheArchiveFile = function (url) {
    // Validate the parameters.
    if (!url) {
        throw new Error('Parameter "url" cannot be null or empty.');
    }

    // Short-circuit if already downloaded.
    console.log('Downloading archive file ' + url);
    var scrubbedUrl = url.replace(/[/\:?]/g, '_');
    var targetPath = path.join(_tempPath, 'archive', scrubbedUrl);
    if (shell.test('-d', targetPath)) {
        console.log('Archive already cached. Skipping.');
        return;
    }

    // Delete any previous partial attempt.
    var partialPath = path.join(_tempPath, 'partial', 'archive', scrubbedUrl);
    if (shell.test('-d', partialPath)) {
        shell.rm('-rf', partialPath);
    }

    // Download the archive file.
    shell.mkdir('-p', partialPath);
    var file = path.join(partialPath, 'file.zip');
    var result = syncRequest('GET', url);
    fs.writeFileSync(file, result.getBody());

    // Extract the archive file.
    console.log("Extracting archive.");
    var directory = path.join(partialPath, "dir");
    var zip = new admZip(file);
    zip.extractAllTo(directory);

    // Move the extracted directory.
    shell.mkdir('-p', path.dirname(targetPath));
    shell.mv(directory, targetPath);

    // Remove the remaining partial directory.
    shell.rm('-rf', partialPath);
}

var cacheNpmPackage = function (name, version) {
    // Validate the parameters.
    if (!name) {
        throw new Error('Parameter "name" cannot be null or empty.');
    }

    if (!version) {
        throw new Error('Parameter "version" cannot be null or empty.');
    }

    // Short-circuit if already downloaded.
    gutil.log('Downloading npm package ' + name + '@' + version);
    var targetPath = path.join(_tempPath, 'npm', name, version);
    if (shell.test('-d', targetPath)) {
        console.log('Package already cached. Skipping.');
        return;
    }

    // Delete any previous partial attempt.
    var partialPath = path.join(_tempPath, 'partial', 'npm', name, version);
    if (shell.test('-d', partialPath)) {
        shell.rm('-rf', partialPath);
    }

    // Write a temporary package.json file to npm install warnings.
    //
    // Note, write the file higher up in the directory hierarchy so it is not included
    // when the partial directory is moved into the target location
    shell.mkdir('-p', partialPath);
    var pkg = {
        "name": "temp",
        "version": "1.0.0",
        "description": "temp to avoid warnings",
        "main": "index.js",
        "dependencies": {},
        "devDependencies": {},
        "repository": "http://norepo/but/nowarning",
        "scripts": {
            "test": "echo \"Error: no test specified\" && exit 1"
        },
        "author": "",
        "license": "MIT"
    };
    fs.writeFileSync(
        path.join(_tempPath, 'partial', 'npm', 'package.json'),
        JSON.stringify(pkg, null, 4));

    // Validate npm is in the PATH.
    var npmPath = shell.which('npm');
    if (!npmPath) {
        throw new Error('npm not found.  ensure npm 3 or greater is installed');
    }

    // Validate the version of npm.
    var versionOutput = cp.execSync('"' + npmPath + '" --version');
    var npmVersion = versionOutput.toString().replace(/[\n\r]+/g, '')
    console.log('npm version: "' + npmVersion + '"');
    if (semver.lt(npmVersion, NPM_MIN_VER)) {
        throw new Error('npm version must be at least ' + NPM_MIN_VER + '. Found ' + npmVersion);
    }

    // Make a node_modules directory. Otherwise the modules will be installed in a node_modules
    // directory further up the directory hierarchy.
    shell.mkdir('-p', path.join(partialPath, 'node_modules'));

    // Run npm install.
    shell.pushd(partialPath);
    try {
        var cmdline = '"' + npmPath + '" install ' + name + '@' + version;
        var result = cp.execSync(cmdline);
        gutil.log(result.toString());
        if (result.status > 0) {
            throw new Error('npm failed with exit code ' + result.status);
        }
    }
    finally {
        shell.popd();
    }

    // Move the intermediate directory to the target location.
    shell.mkdir('-p', path.dirname(targetPath));
    shell.mv(partialPath, targetPath);
}

var cacheNuGetV2Package = function (repository, name, version) {
    // Validate the parameters.
    if (!repository) {
        throw new Error('Parameter "repository" cannot be null or empty.');
    }

    if (!name) {
        throw new Error('Parameter "name" cannot be null or empty.');
    }

    if (!version) {
        throw new Error('Parameter "version" cannot be null or empty.');
    }

    // Cache the archive file.
    cacheArchiveFile(repository.replace(/\/$/, '') + '/package/' + name + '/' + version);
};

var getSemanticVersion = function(done) {
    var options = minimist(process.argv.slice(2), {});
    var version = options.version;
    if (!version) {
        done(new gutil.PluginError('PackageTask', 'supply version with --version'));
        return null;
    }

    if (!semver.valid(version)) {
        done(new gutil.PluginError('PackageTask', 'invalid semver version: ' + version));
        return null;
    }   

    var patch = semver.patch(version) * 1000;
    var prerelease = semver.prerelease(version);
    if (prerelease) {
        patch += prerelease[1];
    }

    return {
        major: semver.major(version),
        minor: semver.minor(version),
        patch: patch,
        getVersionString: function() {
            return this.major.toString() + '.' + this.minor.toString() + '.' + this.patch.toString();
        }
    };
};

gulp.task('copyToWorkingDirectory', ['build'], function (done) {
    shell.mkdir('-p', _wkRoot);  
    
    return es.merge(environments.map(function (env) {
        return gulp.src([path.join(_buildRoot, '**', '*'), 'vss-extension.json', 'extension-icon.png', 'LICENSE.txt', 'overview.md', 'add-task.png'])
        .pipe(gulp.dest(path.join(_wkRoot, env.Name)));
    }));
});

gulp.task('prepareEnvTasks', ['copyToWorkingDirectory'], function (done) {   
    var version = getSemanticVersion(done);
    if (!version) {
        return;
    }    

    return es.merge(environments.map(function (env) {
        return gulp.src(path.join(_wkRoot, env.Name, '**/task*.json'))
        .pipe(pkgm.PrepareEnvForTask(_wkRoot, env, version));
    }));
});

gulp.task('prepareEnvExtension', ['prepareEnvTasks'], function (done) {   
    var version = getSemanticVersion(done);
    if (!version) {
        return;
    }    
    
    return es.merge(environments.map(function (env) {
        return gulp.src(path.join(_wkRoot, env.Name, 'vss-extension.json'))
        .pipe(pkgm.PrepareEnvForExtension(_wkRoot, env, version));
    }));
});

//
// gulp package --version 1.1.2
//
gulp.task('package', ['prepareEnvExtension'], function (done) {       
    shell.mkdir('-p', _pkgRoot);

    return es.merge(environments.map(function (env) {
        return gulp.src(path.join(_wkRoot, env.Name, 'vss-extension.json'))
        .pipe(pkgm.PackageExtension(_pkgRoot, path.join(_wkRoot, env.Name), env));
    }));
});
