// For the cymbal monkey weapon
#include maps\_utility;
#include common_scripts\utility;
#include maps\_zombiemode_utility;

init()
{
	if( !cymbal_monkey_exists() )
	{
		return;
	}

	level._effect["monkey_glow"] 	= loadfx( "maps/zombie/fx_zombie_monkey_light" );
}

player_give_cymbal_monkey()
{
	self giveweapon( "zombie_cymbal_monkey" );
	self set_player_tactical_grenade( "zombie_cymbal_monkey" );
	self thread player_handle_cymbal_monkey();
}

#using_animtree( "zombie_cymbal_monkey" );
player_handle_cymbal_monkey()
{
	//self notify( "starting_monkey_watch" );
	self endon( "disconnect" );
	//self endon( "starting_monkey_watch" );

	// Min distance to attract positions
	attract_dist_diff = level.monkey_attract_dist_diff;
	if( !isDefined( attract_dist_diff ) )
	{
		attract_dist_diff = 45;
	}

	num_attractors = level.num_monkey_attractors;
	if( !isDefined( num_attractors ) )
	{
		num_attractors = 96;
	}

	max_attract_dist = level.monkey_attract_dist;
	if( !isDefined( max_attract_dist ) )
	{
		max_attract_dist = 1536;
	}

	grenade = get_thrown_monkey();
	self thread player_handle_cymbal_monkey();
	if( IsDefined( grenade ) )
	{
		if( self maps\_laststand::player_is_in_laststand() )
		{
			grenade delete();
			return;
		}
		grenade hide();
		model = spawn( "script_model", grenade.origin );
		model SetModel( "weapon_zombie_monkey_bomb" );
		model UseAnimTree( #animtree );
		model linkTo( grenade );
		model.angles = grenade.angles;

		info = spawnStruct();
		info.sound_attractors = [];
		grenade thread monitor_zombie_groans( info );
		velocitySq = 10000*10000;
		oldPos = grenade.origin;
		while( velocitySq != 0 )
		{
			wait( 0.05 );

			if( !isDefined( grenade ) )
			{
				return;
			}

			velocitySq = distanceSquared( grenade.origin, oldPos );
			oldPos = grenade.origin;

			grenade.angles = (grenade.angles[0], grenade.angles[1], 0);
		}
		if( isDefined( grenade ) )
		{
			model thread monkey_cleanup( grenade );

			model unlink();
			model.origin = grenade.origin;
			model.angles = (0, model.angles[1], 0);

			grenade resetmissiledetonationtime();
			PlayFxOnTag( level._effect["monkey_glow"], model, "origin_animate_jnt" );

			valid_poi = check_point_in_active_zone( grenade.origin );

			if( valid_poi )
			{
				valid_poi = check_point_in_playable_area( grenade.origin );
			}

			if(valid_poi)
			{
				model SetAnim( %o_monkey_bomb );
				grenade create_zombie_point_of_interest( max_attract_dist, num_attractors, 0 );
				level notify("attractor_positions_generated");
				grenade thread do_monkey_sound( model, info );
				return;
			}
		}

		self.script_noteworthy = undefined;
		level thread cymbal_monkey_stolen_by_sam( grenade, model );
	}
}

wait_for_attractor_positions_complete()
{
	self waittill( "attractor_positions_generated" );

	self.attract_to_origin = false;
}

monkey_cleanup( parent )
{
	while( true )
	{
		if( !isDefined( parent ) )
		{
			self_delete();
			return;
		}
		wait( 0.05 );
	}
}

do_monkey_sound( model, info )
{
	monk_scream_vox = false;

	if( isdefined(level.monk_scream_trig) && self IsTouching( level.monk_scream_trig))
	{
		self playsound( "zmb_vox_monkey_scream" );
		monk_scream_vox = true;
	}
	else if( level.music_override == false )
	{
		monk_scream_vox = false;
		self playsound( "zmb_monkey_song" );
	}

	self thread play_delayed_explode_vox();

	self waittill( "explode", position );
	if( isDefined( model ) )
	{
		model ClearAnim( %o_monkey_bomb, 0.2 );
	}

	for( i = 0; i < info.sound_attractors.size; i++ )
	{
		if( isDefined( info.sound_attractors[i] ) )
		{
			info.sound_attractors[i] notify( "monkey_blown_up" );
		}
	}

	if( !monk_scream_vox )
	{
		//play_sound_in_space( "zmb_vox_monkey_explode", position );
	}
	else
	{
		thread play_sam_furnace();
	}

	level notify("attractor_positions_generated");
}

play_delayed_explode_vox()
{
	wait(6.5);
	if(isdefined( self ) )
	{
		self playsound( "zmb_vox_monkey_explode" );
	}
}

play_sam_furnace()
{
	wait(2);
	play_sound_2d( "sam_furnace_1" );
	wait(2.5);
	play_sound_2d( "sam_furnace_2" );
}

get_thrown_monkey()
{
	self endon( "disconnect" );
	self endon( "starting_monkey_watch" );

	while( true )
	{
		self waittill( "grenade_fire", grenade, weapName );
		if( weapName == "zombie_cymbal_monkey" )
		{
			return grenade;
		}

		wait( 0.05 );
	}
}

monitor_zombie_groans( info )
{
	self endon( "explode" );

	while( true )
	{
		if( !isDefined( self ) )
		{
			return;
		}

		if( !isDefined( self.attractor_array ) )
		{
			wait( 0.05 );
			continue;
		}

		for( i = 0; i < self.attractor_array.size; i++ )
		{
			if( array_check_for_dupes( info.sound_attractors, self.attractor_array[i] ) )
			{
				if ( isDefined( self.origin ) && isDefined( self.attractor_array[i].origin ) )
				{
					if( distanceSquared( self.origin, self.attractor_array[i].origin ) < 500 * 500 )
					{
						info.sound_attractors = array_add( info.sound_attractors, self.attractor_array[i] );
						self.attractor_array[i] thread play_zombie_groans();
					}
				}
			}
		}
		wait( 0.05 );
	}
}

play_zombie_groans()
{
	self endon( "death" );
	self endon( "monkey_blown_up" );

	while(1)
	{
		if( isdefined ( self ) )
		{
			self playsound( "zmb_vox_zombie_groan" );
			wait randomfloatrange( 2, 3 );
		}
		else
		{
			return;
		}
	}
}

cymbal_monkey_exists()
{
	return IsDefined( level.zombie_weapons["zombie_cymbal_monkey"] );
}

// if the player throws it to an unplayable area samantha steals it
cymbal_monkey_stolen_by_sam( ent_grenade, ent_model )
{
	if( !IsDefined( ent_model ) )
	{
		return;
	}

	direction = ent_model.origin;
	direction = (direction[1], direction[0], 0);

	if(direction[1] < 0 || (direction[0] > 0 && direction[1] > 0))
	{
		direction = (direction[0], direction[1] * -1, 0);
	}
	else if(direction[0] < 0)
	{
		direction = (direction[0] * -1, direction[1], 0);
	}

	// Play laugh sound here, players should connect the laugh with the movement which will tell the story of who is moving it
	players = GetPlayers();
	for( i = 0; i < players.size; i++ )
	{
		if( IsAlive( players[i] ) )
		{
			if( is_true( level.player_4_vox_override ) )
			{
				players[i] playlocalsound( "zmb_laugh_rich" );
			}
			else
			{
				players[i] playlocalsound( "zmb_laugh_child" );
			}
		}
	}

	// play the fx on the model
	PlayFXOnTag( level._effect[ "black_hole_samantha_steal" ], ent_model, "tag_origin" );

	// raise the model
	ent_model MoveZ( 60, 1.0, 0.25, 0.25 );

	// spin it
	ent_model Vibrate( direction, 1.5,  2.5, 1.0 );

	ent_model waittill( "movedone" );

	// delete it
	ent_model Delete();
	if( IsDefined(ent_grenade) )
	{
		ent_grenade Delete();
	}
}