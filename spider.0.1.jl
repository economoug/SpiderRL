using Random
using  AutoHashEquals

struct SolitaireGame
    main_board::Vector{Vector{UInt8}}
    remaining_cards::Vector{UInt8}
    r::Float32
    width::UInt8
    rank_no::UInt8
    total_deck_1to::UInt8
    deck_size::Int
    hidden_deck_depth::UInt8
    game_is_won::Bool
end

struct SolitaireRewards
    step_penalty::Float32
    column_reward::Float32
    win_reward::Float32
    lose_reward::Float32
end


struct HitMe end
const hitme = HitMe()

struct CardMove
    source::UInt8
    depth::UInt8
    dest::UInt8
end

SolitaireMove = Union{HitMe, CardMove}


function SolitaireGame(width=10, rank_no=13, total_deck_1to=8)
    deck_size = rank_no*total_deck_1to

    hidden_deck_depth = (deck_size÷2+1)÷width

    upper_size = hidden_deck_depth*width

    lower_size = deck_size-upper_size

    lower_column_depth = lower_size ÷ width
    taller_lower_columns = lower_size % width

    #initialize and add hidden hards (0 == hidden)

    main_board=[]
    for i in 1:width
        push!(main_board,fill(UInt8(0xFF), lower_column_depth-1 ))
    end
    for i in 1:taller_lower_columns
        push!(main_board[i], 0xFF)
    end

    remaining_cards = shuffle(repeat(1:rank_no, total_deck_1to))

    #deal visible cards

    for i in 1:width
        push!(main_board[i],pop!(remaining_cards))
    end
    SolitaireGame(main_board, remaining_cards, 0.0, width, rank_no, total_deck_1to, deck_size, hidden_deck_depth, false)
end

Base.show(io::IO, m::CardMove) = print(io, "($(m.source)->$(m.dest), $(m.depth))")
function Base.show(io::IO, s::SolitaireGame)
    #replace with - when masked
    for i in 1:s.width
        print(io,"$i ")
    end
    println(io, "-- $(s.hidden_deck_depth) --")
    for i in 1:s.width
        print(io,"--")
    end
    println(io)
    for i in 1:maximum(length.(s.main_board))
        for j in 1:s.width
            if length(s.main_board[j]) >=i
                if(s.main_board[j][i] == 0xFF)
                    print(io, "- ")
                else
                    print(io, string(s.main_board[j][i], base = 16), " ")
                end
            else
                print(io, "  ")
            end
        end

        println(io)
    end
end

function move(s::SolitaireGame, ::HitMe)::SolitaireGame
    if s.hidden_deck_depth == 0
        #println("error: no more cards")
        return s
    end
    #check for empty columns
    for column in s.main_board
        if(isempty(column))
            #println("error: empty column")
            return s
        end
    end
    legal_move(s, HitMe())
end

function is_column_complete(board, column, rank_no)
    i = length(board[column])
    if board[column][i] == 1
        while(i>1 && board[column][i-1] != 0xFF)
            if board[column][i]!=board[column][i - 1] - 1
                return false
            end
            if board[column][i - 1] == rank_no
                return true
            end
            i-=1
        end
    end
    return false
end

function legal_move(s::SolitaireGame, ::HitMe)::SolitaireGame

    new_main_board = deepcopy(s.main_board)

    for column in new_main_board
        push!(column, 0xFF)
    end

    SolitaireGame(new_main_board, s.remaining_cards, 0.0, s.width, s.rank_no, s.total_deck_1to, s.deck_size, s.hidden_deck_depth-1, s.game_is_won)
end

function legal_move(s::SolitaireGame, m::CardMove)
    r = 0.0
    #move chosen column to board
    new_main_board =  copy(s.main_board)

    new_main_board[m.dest] = vcat(new_main_board[m.dest], new_main_board[m.source][(end-m.depth+1):end])
    new_main_board[m.source] = new_main_board[m.source][1:(end - m.depth)]

    #check for complete columns and if game is won
    if is_column_complete(new_main_board, m.dest, s.rank_no)
        r +=0.0#1/s.total_deck_1to
        new_main_board[m.dest] = new_main_board[m.dest][1:(end - s.rank_no)]
    end

    #check if game is over
    game_is_won=false
    if(s.hidden_deck_depth ==0 && foldr(&, isempty.(s.main_board)))
        game_is_won = true
        r+=1.0
    end

    SolitaireGame(new_main_board, s.remaining_cards, r , s.width, s.rank_no, s.total_deck_1to, s.deck_size, s.hidden_deck_depth, game_is_won)
end

function resolve_stochasticity(s)
    r=0.0
    new_main_board = s.main_board
    new_remaining_cards = s.remaining_cards

    #check for complete columns
    for col in 1:s.width
        if !isempty(new_main_board[col]) && new_main_board[col][end] == 0xFF
            if (s.main_board === new_main_board)
                new_main_board = copy(s.main_board)
                new_remaining_cards = copy(s.remaining_cards)
            end

            new_main_board[col] = copy(new_main_board[col])
            new_main_board[col][end] = pop!(new_remaining_cards)

            if is_column_complete(new_main_board, col, s.rank_no)
                r+=0.0#1/s.total_deck_1to
                new_main_board[col] = new_main_board[col][1:(end - s.rank_no)]

                if !isempty(new_main_board[col]) && new_main_board[col][end] == 0xFF
                    new_main_board[col][end] = pop!(new_remaining_cards)

                end
            end
        end

    end
        game_is_won = s.game_is_won
        if(!s.game_is_won && s.hidden_deck_depth ==0 && foldr(&, isempty.(s.main_board)))
            game_is_won = true
            r+=1.0
        end
    SolitaireGame(new_main_board, new_remaining_cards, r, s.width, s.rank_no, s.total_deck_1to, s.deck_size, s.hidden_deck_depth, game_is_won)
end
function move(s::SolitaireGame, m::CardMove)::SolitaireGame

    #check if move is in range
    if m.source ∉ 1:s.width || m.dest ∉ 1:s.width || m.depth>s.rank_no-1 || m.source == m.dest || (length(s.main_board[m.source]))<m.depth
        #println("error: move out of range")
        return s
    end

    #check if chosen depth is movable
    if isempty(s.main_board[m.source])
        #println("error: no cards to move")
        return s
    end

    if s.main_board[m.source][end] == 0xFF
        #println("error: attempted to move hidden card")
        return s
    end

    i = 0
    while i+1 < m.depth
        if s.main_board[m.source][end-i] != s.main_board[m.source][end-i-1] - 1
            #println("error: not movable ")

            return s
        end
        i+=1
    end

    #check if chosen stack can be moved to chosen column
    if !isempty(s.main_board[m.dest]) && s.main_board[m.dest][end] != s.main_board[m.source][end-m.depth+1] + 1
        #println("error: you cant move this stack to the chosen destination ")
        return s
    end

  legal_move(s, m)
end

empty_columns(s) = foldr(|, isempty.(s.main_board))

remaining_deal_deck(s) = s.hidden_deck_depth

column_empty(s,i) = isempty(s.main_board[i])

card_is_hidden(s,column, depth) = (s.main_board[column][end - depth + 1] == 0xFF)

prev_card_is_sequence(s, column, depth) = (depth == 1 || s.main_board[column][end - depth + 1] == s.main_board[column][end - depth + 2] + 1)

source_movable_to_destination(s, source, destination, depth) = (isempty(s.main_board[destination])) || (s.main_board[source][end - depth + 1] == s.main_board[destination][end] - 1)


function generate_legal_moves!(moves::Vector{SolitaireMove} ,s::SolitaireGame)
    empty!(moves)
    #check if HitMe is possible

    for source_column in 1:s.width
        if column_empty(s, source_column)
            continue;
        end
        for depth in 1:(s.rank_no-1)

            if length(s.main_board[source_column]) < depth || card_is_hidden(s,source_column, depth) || ! prev_card_is_sequence(s, source_column, depth)
                break
            end

            for destination_column in 1:s.width
                if source_column != destination_column && source_movable_to_destination(s, source_column, destination_column, depth) && !(isempty(s.main_board[destination_column]) && (length(s.main_board[source_column])- depth == 0))#TODO remove as many unec moves as possible
                    push!(moves, CardMove(source_column, depth, destination_column))
                end
            end
        end
    end

    if(!empty_columns(s) && remaining_deal_deck(s)>0)
        push!(moves, HitMe())
    end


end



using Plots

function train(width=5, rank_no=7, total_deck_1to=4, V = Dict{Tuple{UInt8, Vector{Vector{UInt8}}}, Float64}())
    a = .01
    γ = .99
    ε = 0.1
    dict_init = 0.0
    games_won = 0

    t = plot(Int[],Float32[],ylim=(0,100),
        title = "Winrate %"
        )
    display(t)
    episode_avg =0.0
    moves = Vector{Union{HitMe, CardMove}}()
    for games in 1:100000

        s = SolitaireGame(width, rank_no, total_deck_1to)
        afterstate=s

        generate_legal_moves!(moves, s)
        if(isempty(moves))
            continue
        end
        afterstates::Vector{SolitaireGame} = legal_move.(Ref(s), moves)

        rewards::Vector{Float32} = [a.r for a in afterstates]
        afterstate_keys::Vector{Tuple{UInt8, Vector{Vector{UInt8}}}} = map(x-> (x.hidden_deck_depth ,sort(x.main_board)), afterstates)

        rV_nexts::Vector{Float32} = get.(Ref(V), afterstate_keys, dict_init) .+ rewards
        rV_max,rV_max_idx = findmax(rV_nexts)
        #a = 0.99^a
        α = a#max(0.1, a)
        i=1
        while i<=500

            if(rand(Float64)<ε)
                afterstate = rand(afterstates)
            else
                #max of s.r + V[s]
                afterstate = afterstates[rV_max_idx]

            end
            afterstate_key::Tuple{UInt8, Vector{Vector{UInt8}}} = (afterstate.hidden_deck_depth,sort(afterstate.main_board))

            s = resolve_stochasticity(afterstate)

            generate_legal_moves!(moves, s)
            if(isempty(moves))
                if(s.game_is_won)
                    push!(V, afterstate_key => ((1-α) * get(V,afterstate_key, dict_init) + α * (s.r)) )
                    games_won +=1
                    break
                end

                #d = -2
                #push!(V, afterstate_key => ((1-α) * get(V,afterstate_key, dict_init) + α * (s.r + d*γ)) )
                break
            end
            afterstates = legal_move.(Ref(s), moves)

            afterstate_keys = map(x-> (x.hidden_deck_depth ,sort(x.main_board)), afterstates)
            rewards = [a.r for a in afterstates]
            rV_nexts = get.(Ref(V), afterstate_keys, dict_init) .+ rewards
            rV_max,rV_max_idx = findmax(rV_nexts)

            val = ((1-α) * get(V,afterstate_key, dict_init) + α * (s.r + γ.*rV_max))
            if val !=dict_init
            push!(V, afterstate_key => val)
            end

        # V[afterstate] = V[afterstate](1-α) + α( R + γ*max(rnextnext + Vnextnext))

        i+=1
        end
        episode_avg += (i - episode_avg) / 2000
        if(games%2000==0)
            push!(t,1, games, games_won/20)
            display(t)
            println("Game: $games")
            println("Winrate: $(games_won/20)%")
            println("Dictionary size: $(length(V))")
            println("Average episode length:$(episode_avg)")
            games_won = 0
            episode_avg=0.0
        end
    end

    return V
end

function step(s, V)
    moves = Vector{Union{HitMe,CardMove}}()
    generate_legal_moves!(moves, s)
    afterstates = legal_move.(Ref(s), moves)
    afterstate_keys = map(x-> (x.hidden_deck_depth ,sort(x.main_board)), afterstates)
    rewards = getproperty.(afterstates, :r)
    rV_nexts = get.(Ref(V), afterstate_keys, 0.0) .+ rewards
    rV_max,rV_max_idx = findmax(rV_nexts)

    f=filter(x->x[2]==rV_max, collect(enumerate(rV_nexts)))
    println(collect(zip(moves,rV_nexts)))
    rV_max_idx=(rand(f)[1])
    println(collect(zip(moves,rV_nexts))[rV_max_idx])
    resolve_stochasticity(afterstates[rV_max_idx])
    end


function main(width=10, rank_no=13, total_deck_1to=8)
    total_steps = 0
    move_length_avg = 0.0
    move_length_max = 0.0
    generate_moves_avg = 0
    game_move_avg = 0
    max_column_length = 0
    max_reward = -Inf
    s_max_reward = SolitaireGame()
    moves = Vector{SolitaireMove}()
    sizehint!(moves, width*(width-1)*(rank_no-1) + 1, shrink = false)

    for i in 1:1000
        s=SolitaireGame(width,rank_no,total_deck_1to)
        game_r = 0.0
        for j in 1:1500
            total_steps += 1
            t = time()
            generate_legal_moves!(moves, s)
            if isempty(moves) || j == 500
                game_move_avg += (j - game_move_avg) / i
                if game_r > max_reward
                    max_reward = game_r
                    s_max_reward = s
                end
                break
            end
            afterstates = legal_move.(Ref(s), moves)
            s = rand(afterstates)
            rdet = s.r
            s = resolve_stochasticity(s)
            rstoch = s.r
            game_r+=rstoch+rdet
            generate_moves_avg += (time() - t - generate_moves_avg) / total_steps

            move_length_avg += (length(moves) - move_length_avg) / total_steps
            move_length_max = max(length(moves), move_length_max)
            max_col = maximum(length.(s.main_board))
            max_column_length = max(max_col, max_column_length)

        end
    end
    println("Average legal moves: $move_length_avg")
    println("Average moves per game: $game_move_avg")
    println("Max legal moves: $move_length_max")
    println("Max column length: $max_column_length")
    println("Average generate legal moves + step through all and pick 1 execution time: $generate_moves_avg")
    println("Max reward: $max_reward, $s_max_reward")
    return nothing
end

#using Reactant, Lux

#const dev = reactant_device()

function train_nn(V)







end
#
#all_moves::Vector{SolitaireMove}} = [HitMe()]
#for i in 1:s.width,j in 1:s.width ,depth in 1:s.rank_no
#    push!(all_moves,CardMove(i,depth,j))
#end
#legal_afterstate_moves = Set(move.(Ref(s), moves))
#push!(legal_afterstate_moves,s)
#all_afterstate_moves = Set(move.(Ref(s),all_moves))
#if(!issetequal(legal_afterstate_moves, all_afterstate_moves))
#    print(s)
#    println("$(length(legal_afterstate_moves)) $(length(all_afterstate_moves))--------------PROBLEMO-----------------\n moves:\n $legal_afterstate_moves,\n all_moves: \n $all_afterstate_moves \n $s \nset dif : \n $#(setdiff(all_afterstate_moves,legal_afterstate_moves)) \n")
#   return
#end
