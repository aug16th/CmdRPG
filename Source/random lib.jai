#import "Random";

init_random_seed :: () {
  seed := current_time_consensus().low;
  seed = mix_seed(seed);//scrambles the seed so the lower bits vary

  random_seed(seed);//creates a random seed (it's still using the same random on start)
}

mix_seed :: (x: u64) -> u64 {
    x += 0x9e3779b97f4a7c15;
    x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9;
    x = (x ^ (x >> 27)) * 0x94d049bb133111eb;
    return x ^ (x >> 31);
}

array_random :: (arr: [] $T) -> T {
    if arr.count == 0 {
        empty: T;
        return empty;
    }

    index := cast(int) (random_get() % cast(u64) arr.count);
    //print("count=% index=%\n", arr.count, index);
    //for arr print("  [%] %\n", it_index, it);

    return arr[index];
}

random_bool :: () -> bool {
    return (random_get() & 1) == 1;
}

random_bool_weighted :: (probability: float) -> bool {
    return random_get_zero_to_one() < probability;
}