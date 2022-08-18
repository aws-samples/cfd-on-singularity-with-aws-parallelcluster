#!/bin/bash
#SBATCH --job-name=container-foam-108
#SBATCH --ntasks=108
#SBATCH --output=%x_%j.out
#SBATCH --partition=c5n

export PATH=$PATH:/shared/singularity/bin

module load openmpi
source /shared/OpenFOAM/OpenFOAM-v2012/etc/bashrc

cp $FOAM_TUTORIALS/resources/geometry/motorBike.obj.gz constant/triSurface/

# pre-processing
singularity exec openfoam-ub2004.sif \
	surfaceFeatureExtract  > ./log/surfaceFeatureExtract.log 2>&1

singularity exec openfoam-ub2004.sif \
	blockMesh  > ./log/blockMesh.log 2>&1

singularity exec openfoam-ub2004.sif \
	decomposePar -decomposeParDict system/decomposeParDict.hierarchical  > ./log/decomposePar.log 2>&1

# Meshing
mpirun -np $SLURM_NTASKS \
	singularity exec openfoam-ub2004.sif \
	snappyHexMesh -parallel -overwrite -decomposeParDict system/decomposeParDict.hierarchical   > ./log/snappyHexMesh.log 2>&1

mpirun -np $SLURM_NTASKS \
	singularity exec openfoam-ub2004.sif \
	checkMesh -parallel -allGeometry -constant -allTopology -decomposeParDict system/decomposeParDict.hierarchical > ./log/checkMesh.log 2>&1

mpirun -np $SLURM_NTASKS \
	singularity exec openfoam-ub2004.sif \
	redistributePar -parallel -overwrite -decomposeParDict system/decomposeParDict.ptscotch > ./log/decomposePar2.log 2>&1

mpirun -np $SLURM_NTASKS \
	singularity exec openfoam-ub2004.sif \
	renumberMesh -parallel -overwrite -constant -decomposeParDict system/decomposeParDict.ptscotch > ./log/renumberMesh.log 2>&1

mpirun -np $SLURM_NTASKS \
	singularity exec openfoam-ub2004.sif \
	patchSummary -parallel -decomposeParDict system/decomposeParDict.ptscotch > ./log/patchSummary.log 2>&1

ls -d processor* | xargs -i rm -rf ./{}/0
ls -d processor* | xargs -i cp -r 0.orig ./{}/0

# Run openfoam
mpirun -np $SLURM_NTASKS \
	singularity exec openfoam-ub2004.sif \
	potentialFoam -parallel -noFunctionObjects -initialiseUBCs -decomposeParDict system/decomposeParDict.ptscotch > ./log/potentialFoam.log 2>&1s
mpirun -np $SLURM_NTASKS \
	singularity exec openfoam-ub2004.sif \
	simpleFoam -parallel  -decomposeParDict system/decomposeParDict.ptscotch > ./log/simpleFoam.log 2>&1

