# gambling-sim

*a complete version of this draft project is hosted at kagan019/shape-poker*

This project simulates playing Shape Poker, a game I created to study bluffing. Shape poker is a reduced version of not really poker, but a betting game in general. The point is to be a really simple game to implement in code, so that we can have **a web app that analyzes betting strategies**. Conveniently for us, that is exactly what gambling-sim is! For example, with this app you can:

 - Play against the computer and have it find weaknesses in your play humans did not anticipate
 - Analyze rule sets and determine if some strategies are always more rewarding than other strategies, so you can design games with player motivations in mind
 - Find convergent strategy matchups; i.e. strategies that, when continually tuned to compete with eachother, reach a point when neither can notably improve

"What," might be wondering, "is a 'strategy' exactly, or a 'betting game'?" "How do you play Shape Poker?" "How do I use your app?" If you are wondering any of these things, keep reading! 

## rules of Shape Poker
Players take turns betting on any 2-combination of
	
	◻ ○ △

### setup
Each player has one of the shapes as unique private knowlege, assigned randomly each game.

### gameplay
Players pick a combination of 2 of the 3 possible shapes per turn (◻ ○, ◻ △, or △ ○) which is not currently held by the other player 
  - Player A picks first
  - Play continues until A and B are in the same position as a previous turn
  - Players play infinitely many games of a certain strategy, which is a rule you'll understand later

### winning
The winner is the player with the most points (in the limiting case of a strategy, i.e., after playing infinitely many games)
  - A player is awarded 3 points if they chose both shapes correctly, 1 point if they choose only one of the shapes (could be either the shape they know or the shape the opponent knows), and 0 if they get neither. This reward system corresponds with the random chance of guessing correctly without knowing anything.

## theory
The goal of the player is not to win a single game, such as in poker, but to be **generally better across all games**. The player is not trying to be the most accurate at the game, but to be **the best at identifying and undermining their opponent's strategy in particular**. This is akin to poker for two reasons:
  1. Highly skilled players have an intimate understanding of the probabilities of the game (for Shape Poker, these probabilities are hugely simplified)
  2. Players attack eachother, testing their intuitions for risk and identifying tells that give them an edge (e.g., they blink twice every time they bluff, they move their drink every time the table gets hot, etc)

One way to think of it is as a line of Bayesian reasoning. E.g., given that my opponent played ○ △, knowing them as intimitely as I do, what are the chances that they know ○? If I play ◻ ○ and they respond with ◻ △, then they moved away from ○---what are the chances they know ○ now? Could they be bluffing, even if I am able to end the game here? 

In this simulator, these lines of reasoning are represented as a tensor of decimal probabilities. These are the probabilities that some player will play some bet, given that the opponent played some previous bet. Each column of probabilities should add up to approximately 1, summing all three possible bets the player can make. Since Player A goes first, they have an additional column of probabilities representing the chance they will start play with that bet. The probabilities can be different if the decision would end the game, as the player should know if that were about to happen.

Whatever the hell this contrived data structure is, it is my abstraction---and thereby my definition---of a "strategy." It's not perfect, but it's fine for now. I'm open to suggestions for this.

This is where *theory of mind* plays a role. If a strategy never bluffed at all, theoretically a player would be able to read that and win very easily; similarly if a player ever bluffed predictably, or if a player never assumed that you are bluffing. It would be very easy to take advantage of such a weak player. So ideally (though it is not implemented yet), the weak player's strategy would evolve to understand where the opponent takes advantage of them. *this functionality is implemented in kagan019/shape-poker* Thus ensues a Bayesian arms race, as players add ever more layers of nuance and subterfuge to their play. This is the aim of studying the *limiting case of a strategy*. Will one player ever come out as superior, despite equal natural chances of winning? If so, we say that the players' strategies *converge*. Will they converge to be the same, or different? Will they always converge to the same strategies? If not, how many strategies could they possibly converge to? Does this vary across other betting games?

Speaking of---I also have an abstraction for what a *betting game* is. I'm very sorry about this.

```
	Game G: The full state of a betting game

	  ## Pieces ##

	  Possible Outcomes O: A set of outcomes

	  Public Outcome B(O): An element of O.


	  ## Gameplay ##

	  History H(O, P): The sequence of tuples players' moves (tuples because players can move simultaneously)

	  Tiebreaker A(P): How to settle conflicts between players' next most preferencial move; When a player has to attempt their next ranked move

	  Players P: A set of objects with the following properties

	  	Money D(p <- P): Integer money

	  	Private Outcome b(p <- O, O): An element of O. Known only to this player

	  	Move Ranking m(p <- P, b, i, O, B, H, A, P, D, F, R, T, S, E): A ranking of moves which gives the best payoff. Known only to this player 

	  	Move Condition M(B, b, H): Whether the player is allowed to move this turn

	  	Information i(p <- P, o <- O, P, B, H, F): A player's deductions relating a player, an outcome, and the likelihood that player knows that outcome to be true. Pr(X) = 1 - (U(1 - EP(p, X)) for each player p)


	  ## Statistics ##

	  Outcome Natural Probability F(o <- O): The "pure" probability of O happening, without seeing any gameplay

	  Resource Payoff R(p <- P, B, H): Integer reward given to players after each turn. Should increase with F of some combination of B and p's Private Outcome


	  ## Chores ##

	  Turn T(O, B, H, A, P): Changes to the Public Outcome and History between moves. Only players' top ranking moves, up to the move that succeeded, should be public knowlege.

	  Score(p <- P, P, B): A player's integer score. Should be based on p's resources relative to other player's resources

	  End(B, H, P): Whether to end a game after a turn
```	  

My sincerest apologies. This is not elm code or any language in particular, just a mathy specification for an *interface* of games. Kind of like a mad lib, you can fill in the blanks however you want. Just like my abstraction for a stategy, this abstraction for a betting game also serves as my definition for a betting game. Meaning that, I conjecture that you could describe any betting game in terms of this interface---poker, rummy, backgammon, Cursed Court---*and* absolutely anything you can describe in terms of this interface is necessarily a betting game. This is the scope of games this app seeks to study. If you make a betting game (and you know you did because it can be described completely in terms of this interface), then you can analyze the game with this app.

Good luck implementing your game monadically! 🥶

## how to use the app

Take build/Main.html and drag-and-drop it into a browser window. Or, build it yourself by cloning it and executing:

    elm make src/Main.elm --optimize --output=build/Main.html

in the terminal, given that you've installed elm.

Once the app is open, you will see a lot of numbers, shapes, colors, and no words. Good luck!

Kidding--I'm here to help. You don't actually see the games being played. They are played far too quickly to do that! But you do get to see the players' stats. Player A is red and Player B is blue. You might want to have the app open to the side for the next couple paragraphs. 

At the top is the 'win-ratio' bar. More red means Player A wins more often, more blue means Player B does.

In the middle of the page you see three boxes with the three combinations arranged in a column in each. The columns of numbers in each box should add up to about 1. The red box shows Player A's strategy, and I think you can guess what the blue box does. The numbers on the left side of the box are the chance the player will play the adjacent bet if the game will not end if they play it, the numbers on the right are the chances they will play it if the game would end. The black box at the left does two things. First, it shows you the probability the Player A will begin the game with the adjacent bet. Second, you can click on the shapes to see the players' strategies in response to that play. For example, if you click on ◻ △ in the black box, then the left side of the red box next to ○ △ will read the probability that Player A will play ○ △, if it won't end the game, in response to Player B playing ◻ △. 

Reload the page to generate new random strategies and watch the win ratio converge again.

## results
For all strategies that have been generated, the ratio of points won by Player A to points won by Player B converges with time, and it does so fairly quickly as well. This means that we are allowed to say that some strategy is superior to another strategy, which is the foundational concept for this simulator.

The exact position that the ratio converges along the win-ratio bar is random. Although, it appears that this position tends to be close to the center line, with a roughly equal chance of favoring Player A or Player B. This result would be expected since the game is designed to be fair to both players, and the reward system is perfectly balanced to leverage probability and reward.

These results have not been enforced by empirical, rigorous measurements. For that I offer neither explanation nor apology.

## potential

The strategies are completely static upon load, so they do not depend on what the player knows as hidden knowlege. This is what I consider to be the biggest weakness of the simulator. Before adding any of the other features I suggest below, I recommend that contributors add this first.

More concrete results about Shape Poker can be obtained by programming more metrics about the game into the app, such as how long it generally takes to play games, how the strategy usually tends to win, etc.

The user could use more controls, such as entering custom strategies. This way, they can measure how they play and study it using this app so that they can examine weaknesses in play.

The strategy ought to evolve as play continues. The players should evaluate their performance and adjust accordingly. Vague ideas about how to go about doing that are listed in the source code, in ShapePoker.elm, under the `improveLoserStrategy` definition.


## q&a
**Why is the interface so ugly?**

Because graphics take time and I wrote this in four days the week before finals.

**Why is the code so redundant/sloppy?**

Because refactoring takes time and I wrote this in four days the week before finals.

**Why did you use elm?**

Because the compiler helps to make sure code is correct without having to actually test the app, which takes time. But still, debugging elm wasn't great.

**Is this supposed to be fun?**

Nope! Counterintuitively, it can be surprising how fun something can be when you throw concerns about funness out the window. It needs more work but if this project ever gets a nicer interface and more interactive tools, it could become an engaging little app.

**Are you going to put any more work into this?**

I did, this is just a draft of the simulator. an update of the project is written in Python, is non-graphical, and is hosted at kagan019/shape-poker

**Should I try to contibute?**

no


