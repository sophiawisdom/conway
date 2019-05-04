//
//  main.swift
//  conway
//
//  Created by William Wisdom on 11/16/18.
//  Copyright © 2018 William Wisdom. All rights reserved.
//

/* What if we built up a hashmap of sets describing the results from any given position? The question about how useful this is is how often different positions end up in the same position. It also might be interesting to go back one level, or to try to.
    Try to take advantage of the fact that after the original random distribution, where there are 2^(n^2) different possibilities, there are one less every time. Might be interesting to try to totally profile one of the larger possibility spaces e.g. 10x10
 
    A big improvement now is to make it threadable instead of not being threaded. That would make it a lot easier to run on e.g. an AWS c5.18xlarge with 72 threads or whatever and make it ~72x faster. If this speed improvement could work, it would make things muuch faster. The question is, how do I make a multi-threaded hashmap that works well?
 */

import Foundation

struct Cell: Hashable {
    let row: Int16
    let column: Int16
}

func fuzzConstruct(_ construct: [[Bool]], likeliness: Float) -> [[Bool]] {
    /* Ensures that there are likeliness * width * height bits flipped in the new construct, avoiding potential lack of any bit flips or too many*/
    var child = construct
    let width = Int16(construct.count)
    let height = Int16(construct[0].count)
    let numDifferences: Int = Int(Float(width*height) * likeliness) // Not sure exactly how this works. Does it round up or down?
    var changedIndices: Set<Cell> = []
    while changedIndices.count < numDifferences {
        let randomCell = Cell(row: Int16.random(in: 0..<height), column: Int16.random(in: 0..<width))
        if !(changedIndices.contains(randomCell)) {
            changedIndices.insert(randomCell)
            let value = child[Int(randomCell.row)][Int(randomCell.column)]
            child[Int(randomCell.row)][Int(randomCell.column)] = value != true // flip bit
        }
    }
    return child
}

func randomConstruct(size: Int) -> [[Bool]] {
    let construct = Array(repeating: Array(repeating: false, count: size), count:size)
    return fuzzConstruct(construct, likeliness: 0.5)
}

func cellSetToBitmap(_ cells: Set<Cell>) -> [[Bool]] {
    /* Turn Set<Cell> into [[Bool]] array. Useful for printing, turning a board into a construct, etc. */
    // First, we figure out the necessary size of the array. Then, we allocate the array and place each cell.
    let first = cells.first! // I'm fine with a runtime error if cells doesn't have at least one value.
    var maxRow: Int16 = first.row
    var maxColumn: Int16 = first.column
    var minRow: Int16 = first.row
    var minColumn: Int16 = first.column
    for cell in cells {
        if (cell.row < minRow){
            minRow = cell.row
        }
        if (cell.row > maxRow){
            maxRow = cell.row
        }
        if (cell.column < minColumn){
            minColumn = cell.column
        }
        if (cell.column > maxColumn){
            maxColumn = cell.column
        }
    }
    let columnSize = maxColumn - minColumn
    let rowSize = maxRow - minRow

    var bitmap: [[Bool]] = Array(repeating: Array(repeating: false, count: Int(columnSize)), count: Int(rowSize))
    for cell in cells {
        bitmap[Int(cell.row)][Int(cell.column)] = true
    }
    return bitmap
}

func bitmapToCellState(_ cells: [[Bool]]) -> Set<Cell> {
    var state: Set<Cell> = []
    for (rowIndex, row) in cells.enumerated() {
        for (columnIndex, value) in row.enumerated() {
            if (value == true){
                state.insert(Cell(row: Int16(rowIndex), column: Int16(columnIndex)))
            }
        }
    }
    return state
}

func iterateBoard(_ cells: Set<Cell>) -> Set<Cell> {
    var neighbors: Dictionary<Cell, Int8> = [:] // Maximum number of neighbors = 9, so only int4 necessary.
    for cell in cells {
        let cellNeighbors = [
            Cell(row: cell.row-1, column: cell.column-1),
            Cell(row: cell.row-1, column: cell.column),
            Cell(row: cell.row-1, column: cell.column+1),
            Cell(row: cell.row, column: cell.column-1),
            Cell(row: cell.row, column: cell.column+1),
            Cell(row: cell.row+1, column: cell.column-1),
            Cell(row: cell.row+1, column: cell.column),
            Cell(row: cell.row+1, column: cell.column+1)]
        
        for neighbor in cellNeighbors {
            if let neighborCount = neighbors[neighbor] {
                neighbors[neighbor] = neighborCount+1
            }
            else {
                neighbors[neighbor] = 1
            }
        }
    }
    
    var newState: Set<Cell> = []
    for (currCell, numNeighbors) in neighbors {
        if (numNeighbors == 2){
            if (cells.contains(currCell)) {
                newState.insert(currCell)
            }
        }
        else if (numNeighbors == 3) {
            newState.insert(currCell)
        }
    }
    return newState
}

func childEvolutionConstruct(_ construct: [[Bool]], iterations: Int) -> [[Bool]] {
    /* Creates child construct by evolving it `iterations` ticks and then fuzzing the result  */
    let constructState = bitmapToCellState(construct)
    var iteratedState = iterateBoard(constructState)
    for _ in 1..<iterations { // If more than one, iterate continuously
        iteratedState = iterateBoard(iteratedState)
    }
    let iteratedBitmap = cellSetToBitmap(iteratedState)
    return iteratedBitmap
}

func graphFitness(_ construct: [[Bool]], maxIterations: Int) -> (Int, Int, Int) {
    var previousStates: Set<Set<Cell>> = []
    var currState: Set<Cell> = bitmapToCellState(construct)
    let maxRow = maxIterations/10
    let maxColumn = maxIterations/10
    var totalCellCount = currState.count;
    var cellsCreated = 0
    

    for iteration in 0..<maxIterations {
        var neighbors: Dictionary<Cell, Int8> = [:] // Maximum number of neighbors = 9, so only int4 necessary, but pointer to Int8 is 16x the 4 bits this would save
        // For each cell, add 1 to the neighbor count for all the cells around it
        for cell in currState {
            let cellNeighbors = [
                Cell(row: cell.row-1, column: cell.column-1),
                Cell(row: cell.row-1, column: cell.column),
                Cell(row: cell.row-1, column: cell.column+1),
                Cell(row: cell.row, column: cell.column-1),
                Cell(row: cell.row, column: cell.column+1),
                Cell(row: cell.row+1, column: cell.column-1),
                Cell(row: cell.row+1, column: cell.column),
                Cell(row: cell.row+1, column: cell.column+1)]
            
            for neighbor in cellNeighbors {
                if let neighborCount = neighbors[neighbor] {
                    neighbors[neighbor] = neighborCount+1
                }
                else {
                    neighbors[neighbor] = 1
                }
            }
        }
        
        var newState: Set<Cell> = []
        for (currCell, numNeighbors) in neighbors {
            if (numNeighbors == 2){
                if (currState.contains(currCell)) {
                    if (abs(currCell.column) < maxColumn && abs(currCell.row) < maxRow){
                        newState.insert(currCell)
                    }
                }
            }
            else if (numNeighbors == 3) {
                if (abs(currCell.column) < maxColumn && abs(currCell.row) < maxRow){
                    newState.insert(currCell)
                }
                if (!currState.contains(currCell)){ // newly created
                    cellsCreated += 1
                }
            }
        }
        totalCellCount += newState.count

        if (previousStates.contains(newState) || newState.count == 0) {
            return (iteration, totalCellCount, cellsCreated)
        }
        
        previousStates.insert(newState)
        currState = newState
    }
    return (maxIterations, totalCellCount, cellsCreated)
}

func generation(numConstructs: Int, maxIterations: Int, initSize: Int) {
    var constructsAboveThreshold: [([[Bool]], (Int, Int, Int))] = [] // Construct ([[Bool]]), (fitness, fitness, fitness)
    var generation: [[[Bool]]] = []
    for _ in 0..<numConstructs {
        generation.append(randomConstruct(size: initSize))
    }
    let bar = maxIterations/2
    var totalCellCount = 0
    for construct in generation {
        let fitness = graphFitness(construct, maxIterations: maxIterations)
        if (fitness.0 > bar){
            constructsAboveThreshold.append((construct, fitness))
            totalCellCount += fitness.1
        }
    }
    
    let maxSize = initSize*2
    generation = []
    for (construct, fitness) in constructsAboveThreshold {
        let childCount: Int = (fitness.1/totalCellCount * (numConstructs - constructsAboveThreshold.count)) + 1
        let size = construct.count // It doesn't matter if one part is bigger than the other, because when they are evolved, they are made to have equal widths and lengths anyway.
        let childBitmap: [[Bool]]
        if (size < maxSize){
            childBitmap = childEvolutionConstruct(construct, iterations: 1)
        }
        else {
            childBitmap = construct
        }
        for _ in 0..<childCount {
            generation.append(fuzzConstruct(childBitmap, likeliness: 0.1))
        }
    }
}

func manageGenerations(size: Int, maxIterations: Int, numConstructs: Int) -> [([[Bool]], Int)] {
    var allPositions: Dictionary<Set<Cell>, Int> = [:] // All positions that have ever been encountered -> number of iterations it survives
    var collisions = 0
    var totalIterations = 0
    var iterationsSaved = 0
    var firstDateTime = Date().timeIntervalSinceReferenceDate
    
    // Diagnostics
    var lastCollisions = 0
    var lastIterationsSaved = 0
    var lastTotalIterations = 0
    var sizeAtCollision = 0
    
    var allConstructs: [([[Bool]], Int)] = []
    
    for constructIndex in 0..<numConstructs {
        let construct = randomConstruct(size: size)
        // Below is basically a copy of graphFitness but with the addition of updating allPositions after the end and checking allPositions while it's running
        var currState: Set<Cell> = bitmapToCellState(construct)
        var previousStates: Set<Set<Cell>> = []
        let maxRow = maxIterations/10
        let maxColumn = maxIterations/10
        var totalCellCount = currState.count
        var cellsCreated = 0
        var endingIter = -1 // Sentinel value - if it breaks before the end, then this is set to the iteration at which it breaks. Otherwise, it stays at -1 until the end of the iteration
        var hasCollided = false
        var collisionIter = 0
        
        let diagnosticsFreq = 1000
        
        if (constructIndex % diagnosticsFreq) == 0 && constructIndex != 0 {
            let secondDateTime = Date().timeIntervalSinceReferenceDate
            print("Took \(secondDateTime - firstDateTime) seconds to run the last \(diagnosticsFreq) constructs. Since last time, there have been \(collisions-lastCollisions) collisions that could have saved \(iterationsSaved-lastIterationsSaved) iterations out of \(totalIterations-lastTotalIterations) total iterations. Potential savings of \(Double(iterationsSaved-lastIterationsSaved)/Double(totalIterations-lastTotalIterations) * 100)%. Average size at collision \(Double(sizeAtCollision)/Double(collisions))")
            lastCollisions = collisions
            lastIterationsSaved = iterationsSaved
            lastTotalIterations = totalIterations
            firstDateTime = secondDateTime
            sizeAtCollision = 0
        }
        
        for iteration in 0..<maxIterations {
            /*
            if allPositions[currState] != nil && hasCollided == false {
                collisions += 1
//                endingIter = iteration + collisionIter // How long did it take to get here and how long after that does this state survive
                hasCollided = true
                collisionIter = iteration;
                sizeAtCollision += currState.count;
            }*/
            var neighbors: Dictionary<Cell, Int8> = [:] // Maximum number of neighbors = 9, so only int4 necessary, but pointer to Int8 is 16x the 4 bits this would save
            for cell in currState {
                let cellNeighbors = [
                    Cell(row: cell.row-1, column: cell.column-1),
                    Cell(row: cell.row-1, column: cell.column),
                    Cell(row: cell.row-1, column: cell.column+1),
                    Cell(row: cell.row, column: cell.column-1),
                    
                    Cell(row: cell.row, column: cell.column+1),
                    Cell(row: cell.row+1, column: cell.column-1),
                    Cell(row: cell.row+1, column: cell.column),
                    Cell(row: cell.row+1, column: cell.column+1)]
                
                for neighbor in cellNeighbors {
                    if let neighborCount = neighbors[neighbor] {
                        neighbors[neighbor] = neighborCount+1
                    }
                    else {
                        neighbors[neighbor] = 1
                    }
                }
            }
            
            var newState: Set<Cell> = []
            for (currCell, numNeighbors) in neighbors {
                if (numNeighbors == 2){
                    if (currState.contains(currCell)) {
                        if (abs(currCell.column) < maxColumn && abs(currCell.row) < maxRow){
                            newState.insert(currCell)
                        }
                    }
                }
                else if (numNeighbors == 3) {
                    if (abs(currCell.column) < maxColumn && abs(currCell.row) < maxRow){
                        newState.insert(currCell)
                    }
                    if (!currState.contains(currCell)){ // newly created
                        cellsCreated += 1
                    }
                }
            }
            totalCellCount += newState.count
            
            if (previousStates.contains(newState) || newState.count == 0) {
                endingIter = iteration
                break
            }
            if let moreIters = allPositions[newState] {
                endingIter = iteration + moreIters
                break
            }
            
            previousStates.insert(newState)
            currState = newState
        }
        if endingIter == -1 {
            endingIter = maxIterations
        }
        totalIterations += endingIter
        for (iter, state) in previousStates.enumerated() {
            allPositions[state] = endingIter - iter // How long does this state survive
        }
        
        if hasCollided == true {
            iterationsSaved += (endingIter - collisionIter)
        }
        
        allConstructs.append((construct, endingIter))
    }
    return allConstructs
}

let currentDateTime = Date().timeIntervalSinceReferenceDate

var iterations: [Int] = []
var num_max = 0
var numConstructs = 10000
let maxIterations = 10000

var size = 5
let arguments = CommandLine.arguments
if arguments.count >= 2 {
    if arguments.count >= 3 {
        numConstructs = Int(arguments[2])!
    }
    size = Int(arguments[1])!
}
print("Creating \(numConstructs) constructs with average size \(size)")

/*
for _ in 0...numConstructs {
    let construct = randomConstruct(size: size)
    let fitness = graphFitness(construct, maxIterations: maxIterations)
    iterations.append(fitness.0)
    totalIterations += fitness.0
    if (fitness.0 == maxIterations){
        num_max += 1
    }
}*/

var allConstructs = manageGenerations(size: size, maxIterations: maxIterations, numConstructs: numConstructs)
allConstructs.sort {
    $0.1 > $1.1
}

for construct in allConstructs[0...100] {
    for grouping in construct.0 {
        for letter in grouping {
            if letter == false {
                print(" ", terminator:"")
            } else {
                print("*", terminator:"")
            }
        }
        print("\n")
    }
    print(construct.1);
}
