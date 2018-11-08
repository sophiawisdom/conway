#include <stdio.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <sys/time.h>

#include "uthash/include/uthash.h"

#define MAX(a,b) ((a) > (b) ? (a) : (b))


/* TODO

* Fix randomness in fitness process. Should be more obvious. Placing the construct on the board is
* failing for whatever reason, so idk.

* More interesting fitness function - maximum number of tiles covered. I think that incentivizes
* being big appropriately, even if you fail in the process and become smaller.

* Make generation of constructs more efficient/better - 25% chance to make it a 1 instead of 50%?
* Every so often, compare curr board state with previous board state - if they're the same,
* then stop simulating.
* Potential improvement to that would be to think about it as a graph. If the state ever loops back to
* somewhere it was before, then there's no need for further simulation. This could also be a loss
* function - number of iterations before self-loop.

* Instead of iterating over every cell, only iterate over cells with items in them. Maybe instead of
* current_cells, it could be an array containing currently active indexes, so we would only have to 
* simulate those.


* Cells would be implemented as hashmap. Each key would be (row << 16 | column). If you want to check
* If e.g. [7,5] is set, 7 << 16 | 5 is an int which you can index into the hashmap with. When doing
* neighbor checking, implement that as a hashmap too to represent how many neighbors everything has.
* I think this makes perfect sense and is the best representation.
*/

struct cell {
	short row;
	short column;
	UT_hash_handle hh;
};

struct construct {
	int width;
	int height;
	char *constr;
	bool is_child;
};

struct children_data {
	int left_over;
	int *children_counts;
};

int first_hash_key(struct board_state current_cells){
	int key = 0;
	for (int i = 0; i < current_cells.num_cells; i++){
		struct cell current_cell = current_cells[i];
		key ^= (current_cell.row << 16 | current_cell.column);
	}
	return key;
}

int second_hash_key(struct board_state current_cells){
	int key = -1;
	for (int i = 0; i < current_cells.num_cells; i++){
		struct cell current_cell = current_cells[i];
		key ^= (current_cell.column << 16 | current_cell.row);
	}
	return key;
}


void display_neighbors(char *neighbors, struct board_state *board){
	int index = 0;
	printf("neighbors:\n");
	for (int w = 0; w < board -> width; w++){
		for (int h = 0; h < board -> height; h++){
			printf("%d ",neighbors[index]);
			index += 1;
		}
		printf("\n");
	}
	printf("end of neighbors\n");
}

void display_board(struct board_state *board){
	int index = 0;
	for (int w = 0; w < board -> width; w++){
		for (int h = 0; h < board -> height; h++){
			printf("%c ",board -> current_cells[index] ? '1' : '0');
			index += 1;
		}
		printf("\n");
	}
}

void display_construct(struct construct *constr){
	int index = 0;
	for (int w = 0; w < constr -> width; w++){
		for (int h = 0; h < constr -> height; h++){
			printf("%c ",constr -> constr[index] ? '1' : '0');
			index += 1;
		}
		printf("\n");
	}
}

void display_indices(struct board_state *board){
	int index = 0;
	for (int w = 0; w < board -> width; w++){
		for (int h = 0; h < board -> height; h++){
			printf("%d ",index);
			index += 1;
		}
		printf("\n");
	}
}

struct construct *random_construct(int width, int height){
	struct construct *constr = malloc(sizeof(struct construct));
	constr -> constr = malloc(width*height*sizeof(char));
	constr -> width = width;
	constr -> height = height;
	constr -> is_child = false;
	int size = width*height;
	for (int i = 0; i < size; i++) {
		constr -> constr[i] = (((float) random())/RAND_MAX) < .2; // 1/5 chance
	}
	return constr;
}

struct construct *child_construct(struct construct *parent){
	int size = (parent -> width) * (parent -> height);
	struct construct* child = malloc(sizeof(struct construct));
	child -> constr = malloc(size);
	child -> width = parent -> width;
	child -> height = parent -> height;
	child -> is_child = true;
	memcpy(child -> constr, parent -> constr, size);
	for (int i = 0; i < size; i++){
		if (((float) random())/RAND_MAX < .1){
			if (child -> constr[i]){
				child -> constr[i] = 0;
			}
			else {
				child -> constr[i] = 1;
			}
		}
	}
	return child;
}

int total_visits(struct board_state *board){
	unsigned int total_visits = 0;
	int size = board -> width*board -> height;
	for (int i = 0; i < size; i++){
		total_visits += board -> num_visits[i];
	}
	return total_visits;
}

char *get_neighbors(struct cell *board){
	// Input is a UTHash hash table of all the cells
	struct cell *neighbors = NULL; // Neighbors hash table
	struct cell *neighbor_cell;
	struct cell *curr_cell;
	for (neighbor_cell = board; neighbor_cell != NULL; neighbor_cell=neighbor_cell->hh.next){
		int key = (neighbor_cell -> row << 16) | (neighbor_cell -> column);
		HASH_FIND_INT(neighbors, &key, neighbor_cell);
		if (neighbor_cell == NULL){ // Nothing here
			
		}
	}
}

void iterate(struct board_state *board){
	int size = board -> width * board -> height;
	for (int i = 0; i < size; i++){
		board -> num_visits[i] += board -> current_cells[i];
	}

	char *neighbors = get_neighbors(board);
	for (int i = 0; i < size; i++){
		if (neighbors[i] <= 1){
			board -> current_cells[i] = 0;
		}
		else if (neighbors[i] == 3){
			board -> current_cells[i] = 1;
		}
		else if (neighbors[i] >= 4) {
			board -> current_cells[i] = 0;
		}
	}
	free(neighbors);
}

struct board_state* instantiate_board(){
	struct board_state *board = malloc(sizeof(struct board_state));
	board -> num_cells = 0;
	board -> cell_size = 100;
	board -> cells = malloc(100 * sizeof(struct cell))
	return board;
}

void destroy_board(struct board_state* board){
	free(board -> ceslls);
	free(board);
}

int get_construct_fitness(struct construct *constr, int board_width, int board_height, int iterations){
	assert((constr -> width < board_width) || (constr -> height < board_height));
	struct board_state *board = instantiate_board(board_width, board_height);

	struct board_state *past_board_states = NULL; // our hash table used by UTHASH

	// Set approximate middle of board equal to construct - place construct in board


	for (int i = 0; i < iterations; i++){
		iterate(board);

		struct board_state *dummy_state;
		int hash_key = get_hash_key(*board);
		HASH_FIND_INT( past_board_states, &hash_key, dummy_state);
		if (dummy_state != NULL) { // We have reached a state with this hash before. Fail if it isn't this state, return i if it is.
			assert(dummy_state -> num_Cells == board -> num_cells);
			int cell_size = dummy_state -> num_cells * sizeof(struct cell);
			assert(memcmp(board -> cells, dummy_state -> cells, cell_size) == 0); // fail if same key different array
			break;
		}
		else {
			HASH_ADD_INT( past_board_states, hash_key, board );
		}
	}

	destroy_board(board);
	return i;
}

struct construct** initialize_generation(int num_constructs, int constr_width, int constr_height){
	struct construct **generation = malloc(num_constructs * sizeof(struct construct *));
	for (int i = 0; i < num_constructs; i++){
		generation[i] = random_construct(constr_width, constr_height);
	}
	return generation;
}

struct children_data* children_counts(int *fitnesses, int fitness_len, int num_children){
	int *children = malloc(fitness_len*sizeof(int));
	double sum = 0;
	for (int i = 1; i <= fitness_len; i++){
		sum += (1.0/i);
	}
	int multiplier = (num_children-fitness_len)/sum;
	int children_alloced = 0;
	for (int i = 1; i <= fitness_len; i++){
		int num = (multiplier/i) + 1;
		children_alloced += num;
		children[i-1] = num;
	}
	struct children_data *result = malloc(sizeof(struct children_data));
	result -> left_over = (num_children - children_alloced);
	result -> children_counts = children;
	return result;
}

struct fitness_val {
	int fitness;
	int index;
};

int fitness_comp(const void * elem1, const void * elem2) 
{
	// RETURNS INVERSE OF ACCURATE - sorts from high to low
    struct fitness_val first = *((struct fitness_val *)elem1);
    struct fitness_val second = *((struct fitness_val *)elem2);

    if (first.fitness > second.fitness) return -1;
    if (first.fitness < second.fitness) return  1;
    return 0;
}


int main(int argc, char **argv){
	srandomdev();
	int num_constructs = 1000;
	if (argc >= 2){
		num_constructs = atoi(argv[1]);
	}
	int num_generations = 1000;
	int construct_width = 6;
	int construct_height = 6;
	struct construct** constructs = initialize_generation(num_constructs, construct_width, construct_height);
	int max_fitness = 0;

	for (int generation = 0; generation < num_generations; generation++){
		struct timeval generation_beginning;
		struct timeval generation_ending;
		gettimeofday(&generation_beginning, NULL);
		// long long instead of int because I want to store fitness and index
		int total_fitness = 0;
		struct fitness_val *fitness = malloc(num_constructs * sizeof(struct fitness_val));
		int child_fitness = 0;
		int child_constructs = 0;
		for (int i = 0; i < num_constructs; i++){
			int f = get_construct_fitness(constructs[i], 50, 50, 300);
			fitness[i].index = i;
			fitness[i].fitness = f;
			total_fitness += f;
			if (constructs[i] -> is_child){
				child_fitness += f;
				child_constructs += 1;
			}
		}
		double avg_child_fitness = 0;
		if (child_constructs){ // otherwise we get divide by 0
			avg_child_fitness = child_fitness/child_constructs;
		}
		double avg_random_fitness = (total_fitness-child_fitness)/(num_constructs-child_constructs);
		double avg_fitness = total_fitness/num_constructs;
		double bar = avg_fitness*2;
		printf("Average fitness for generation %d is %f. Bar is %f. Avg child fitness: %f, random %f\n", generation, avg_fitness, bar, avg_child_fitness, avg_random_fitness);

		qsort(fitness, num_constructs, 8, fitness_comp);

//		printf("Sorted fitness array\n");

		struct construct** parent_constructs = malloc(num_constructs*sizeof(struct construct *));
		int num_above_bar = 0;
		for (; num_above_bar < num_constructs; num_above_bar++){
			struct fitness_val result = fitness[num_above_bar];
			if (result.fitness < bar){
				break;
			}
			parent_constructs[num_above_bar] = constructs[result.index];
		}

		if (max_fitness != fitness[0].fitness){
			printf("Top construct has fitness %d and %s a child\n", fitness[0].fitness, constructs[fitness[0].index] -> is_child ? "is" : "is not");
			display_construct(constructs[fitness[0].index]);
			max_fitness = fitness[0].fitness;
		}

//		printf("Got past deciding which constructs to reproduce\n");

		// Don't free parents because they are still going to be used
		for (int i = num_above_bar; i < num_constructs; i++){
			int index = fitness[i].index;
			free(constructs[index] -> constr);
			free(constructs[index]);
		}

//		printf("Got past freeing bad constructs\n");

		int *just_fitnesses = malloc(num_above_bar*sizeof(int));
		for (int i = 0; i < num_above_bar; i++){
			just_fitnesses[i] = fitness[i].fitness;
		}
		free(fitness);

		printf("Generated just fitnesses and freed fitnesses. %d above bar\n", num_above_bar);

		int num_children = num_constructs - num_above_bar;
		struct children_data *child_data = children_counts(just_fitnesses, num_above_bar, num_children);
		int left_over = child_data -> left_over;
		int *children = child_data -> children_counts;
		free(child_data);
		int index = 0;
		for (int i = 0; i < num_above_bar; i++){
			int new_children = children[i];
			struct construct* parent_construct = parent_constructs[i];
			for (int j = 0; j < new_children; j++){
				constructs[index] = child_construct(parent_construct);
				if (random()&15 == 0){
					display_construct(constructs[index]);
				}
				index += 1;
			}
			constructs[index] = parent_construct;
			index += 1;
		}

		for (int i = 0; i < left_over; i++){
			constructs[index] = random_construct(construct_width, construct_height);
			index += 1;
		}

		free(children);
		free(just_fitnesses);
		free(parent_constructs);

		gettimeofday(&generation_ending, NULL);
		double time_taken = ((generation_ending.tv_sec - generation_beginning.tv_sec)*1000000) + (generation_ending.tv_usec - generation_beginning.tv_usec);
		time_taken /= 1000000.0;
		printf("Generation %d took %f seconds\n", generation, time_taken);
	}
}