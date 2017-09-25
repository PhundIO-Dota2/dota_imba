--[[
		By: AtroCty
		Prev. Authors: Firetoad
		Date:  04.08.2015
		Updated:  23.04.2017
	]]

CreateEmptyTalents("sven")

-------------------------------------------
--            STORM BOLT
-------------------------------------------
LinkLuaModifier("modifier_imba_storm_bolt_caster", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_storm_bolt_crit", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_storm_bolt_talent_drag", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_storm_bolt_talent_reduction", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)

imba_sven_storm_bolt = class({})
function imba_sven_storm_bolt:IsHiddenWhenStolen() return false end
function imba_sven_storm_bolt:IsRefreshable() return true end
function imba_sven_storm_bolt:IsStealable() return true end
function imba_sven_storm_bolt:IsNetherWardStealable() return false end

function imba_sven_storm_bolt:GetAbilityTextureName()
   return "sven_storm_bolt"
end
-------------------------------------------

function imba_sven_storm_bolt:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		self.target = self:GetCursorTarget()
		
		-- Parameters
		local damage = self:GetSpecialValueFor("damage")
		local stun_duration = self:GetSpecialValueFor("stun_duration")
		local radius = self:GetTalentSpecialValueFor("radius")
		local vision_radius = self:GetSpecialValueFor("vision_radius")
		local bolt_speed = self:GetSpecialValueFor("bolt_speed")
		
		-- Play sound
		caster:EmitSound("Hero_Sven.StormBolt")

		-- Randomly play a cast line
		if (math.random(1,100) <= 50) and (caster:GetName() == "npc_dota_hero_sven") then
			caster:EmitSound("sven_sven_ability_stormbolt_0"..math.random(1,9))
		end

		-- Remove caster from the world
		caster:AddNewModifier(caster, self, "modifier_imba_storm_bolt_caster", {})
		caster:AddNoDraw()
		
		local projectile = 
		{
			Target 				= self.target,
			Source 				= caster,
			Ability 			= self,
			EffectName 			= "particles/units/heroes/hero_sven/sven_spell_storm_bolt.vpcf",
			iMoveSpeed			= bolt_speed,
			vSpawnOrigin 		= caster:GetAbsOrigin(),
			bDrawsOnMinimap 	= false,
			bDodgeable 			= true,
			bIsAttack 			= false,
			bVisibleToEnemies 	= true,
			bReplaceExisting 	= false,
			flExpireTime 		= GameRules:GetGameTime() + 10,
			bProvidesVision 	= true,
			iSourceAttachment 	= DOTA_PROJECTILE_ATTACHMENT_ATTACK_2,
			iVisionRadius 		= vision_radius,
			iVisionTeamNumber 	= caster:GetTeamNumber(),
			ExtraData			= {damage = damage, stun_duration = stun_duration, radius = radius, speed = bolt_speed, target_pos_x = self.target:GetAbsOrigin().x, target_pos_y = self.target:GetAbsOrigin().y, target_pos_z = self.target:GetAbsOrigin().z}
		}
		ProjectileManager:CreateTrackingProjectile(projectile)
	end
end

function imba_sven_storm_bolt:OnProjectileThink_ExtraData(location, ExtraData)
	local caster = self:GetCaster()
	if caster:HasTalent("special_bonus_imba_sven_6") then
		local drag_radius = caster:FindTalentValue("special_bonus_imba_sven_6","drag_radius")
		local enemies = FindUnitsInRadius(caster:GetTeamNumber(), location, nil, drag_radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
		for _,enemy in ipairs(enemies) do
                        if not enemy:IsMagicImmune() then
			enemy:AddNewModifier(caster, self, "modifier_stunned", {duration = ExtraData.stun_duration})
			local drag_mod = enemy:FindModifierByName("modifier_imba_storm_bolt_talent_drag")
			if not drag_mod then
			drag_mod = enemy:AddNewModifier(enemy,self,"modifier_imba_storm_bolt_talent_drag",{})
			end
			if drag_mod then
			drag_mod.pos_x = ExtraData.target_pos_x
			drag_mod.pos_y = ExtraData.target_pos_y
			drag_mod.pos_z = ExtraData.target_pos_z
			drag_mod.speed = ExtraData.speed
			end
                        end
		end
	end
end

modifier_imba_storm_bolt_talent_drag = class({})
function modifier_imba_storm_bolt_talent_drag:IsHidden() return false end
function modifier_imba_storm_bolt_talent_drag:IsDebuff() return true end
function modifier_imba_storm_bolt_talent_drag:IsPurgable() return false end
function modifier_imba_storm_bolt_talent_drag:IsPurgeException()return true end
function modifier_imba_storm_bolt_talent_drag:IsMotionController()  return true end
function modifier_imba_storm_bolt_talent_drag:GetMotionControllerPriority()  return DOTA_MOTION_CONTROLLER_PRIORITY_HIGH end

function modifier_imba_storm_bolt_talent_drag:OnCreated()
	if IsServer() then
	self.target = self:GetParent()
	self.caster = self:GetCaster()
	self.frametime = FrameTime()
	
	self:StartIntervalThink(self.frametime)
	end
end

function modifier_imba_storm_bolt_talent_drag:OnIntervalThink()
	-- Remove the motion controllers if there aren't any
	if not self:CheckMotionControllers() then
		self:Destroy()
		return nil
	end
	
	self.destination = Vector(self.pos_x,self.pos_y,self.pos_z)
	
	self:HorizontalMotion(self.target, self.frametime)
end

function modifier_imba_storm_bolt_talent_drag:HorizontalMotion()
	if IsServer() then
		-- Check if the target is alive
		if not self.target:IsAlive() then
			self:Destroy()
			return nil
		end
		
		-- Ability Specials
		local target_position = self.target:GetAbsOrigin()
		
		-- Direction
		local direction = ( self.destination - target_position ):Normalized()
		
		-- Distance
		local distance = ( self.destination - target_position ):Length2D()
		
		-- Destroys itself when it reached the destination
		if distance <= FrameTime() * self.speed then
			self:Destroy()
		else
			-- DRAG IT!
			local newPosition = target_position + direction * FrameTime() * self.speed
				
			-- Set the new point
			self.target:SetAbsOrigin(newPosition)
		end
	end
end

function modifier_imba_storm_bolt_talent_drag:OnDestroy()
	if IsServer() then
		self.target:SetUnitOnClearGround()
	end
end

function imba_sven_storm_bolt:OnProjectileHit_ExtraData(target, location, ExtraData)
	if IsServer() then
		local caster = self:GetCaster()
		
		-- Play sound
		EmitSoundOnLocationWithCaster(location, "Hero_Sven.StormBoltImpact", caster)
		caster:RemoveModifierByName("modifier_imba_storm_bolt_caster")
		caster:RemoveNoDraw()
		if target then
			-- Teleport the caster to the target
			local target_pos = target:GetAbsOrigin()
			local caster_pos = caster:GetAbsOrigin()
			local blink_pos = target_pos + ( caster_pos - target_pos ):Normalized() * 100
			FindClearSpaceForUnit(caster, blink_pos, true)

			-- Randomly play a cast line
			if (( target_pos - caster_pos ):Length2D() > 600) and (RandomInt(1, 100) <= 20) and (caster:GetName() == "npc_dota_hero_sven") then
				caster:EmitSound("sven_sven_ability_teleport_0"..math.random(1,3))
			end
			
			-- #3 Talent: Grants Sven 4 second damage reduction after reaching the target
			if caster:HasTalent("special_bonus_imba_sven_3") then
			caster:AddNewModifier(caster, self, "modifier_imba_storm_bolt_talent_reduction", {duration = caster:FindTalentValue("special_bonus_imba_sven_3","duration")})
			end
			
			-- Start attacking the target + apply crit
			caster:SetAttacking(target)
			local crit_max_duration = self:GetSpecialValueFor("crit_max_duration")
			caster:AddNewModifier(caster, self, "modifier_imba_storm_bolt_crit", {duration = crit_max_duration})
			
			local enemies = FindUnitsInRadius(caster:GetTeamNumber(), location, nil, ExtraData.radius, self:GetAbilityTargetTeam(), self:GetAbilityTargetType(), self:GetAbilityTargetFlags(), FIND_ANY_ORDER, false)
			for _,enemy in ipairs(enemies) do
				if enemy == target and target:TriggerSpellAbsorb(self) then
				else
					ApplyDamage({victim = enemy, attacker = caster, ability = self, damage = ExtraData.damage, damage_type = self:GetAbilityDamageType()})
					enemy:AddNewModifier(caster, self, "modifier_stunned", {duration = ExtraData.stun_duration})
				end
			end
		end
	end
end

function imba_sven_storm_bolt:GetAOERadius()
	return self:GetTalentSpecialValueFor("radius")
end

function imba_sven_storm_bolt:GetCooldown( nLevel )
	return self.BaseClass.GetCooldown( self, nLevel )
end

modifier_imba_storm_bolt_talent_reduction = class({})

function modifier_imba_storm_bolt_talent_reduction:IsDebuff() return false end
function modifier_imba_storm_bolt_talent_reduction:IsHidden() return false end
function modifier_imba_storm_bolt_talent_reduction:IsPurgable() return true end
function modifier_imba_storm_bolt_talent_reduction:IsStunDebuff() return false end
function modifier_imba_storm_bolt_talent_reduction:RemoveOnDeath() return true end

function modifier_imba_storm_bolt_talent_reduction:DeclareFunctions()
	local funcs =
	{
		MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
	}
	return funcs
end

function modifier_imba_storm_bolt_talent_reduction:GetModifierIncomingDamage_Percentage()
	return self:GetCaster():FindTalentValue("special_bonus_imba_sven_3") * (-1)
end

-- Warcry particles
function modifier_imba_storm_bolt_talent_reduction:OnCreated()
	local caster = self:GetCaster()
	local parent = self:GetParent()
	local caster_loc = caster:GetAbsOrigin()
	
	if self.cast_fx then
		ParticleManager:DestroyParticle(self.cast_fx, false)
		ParticleManager:ReleaseParticleIndex(self.cast_fx)
	end
	self.cast_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_spell_warcry.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(self.cast_fx, 0, caster, PATTACH_POINT_FOLLOW, nil, caster_loc, true)
	ParticleManager:SetParticleControlEnt(self.cast_fx, 1, caster, PATTACH_POINT_FOLLOW, nil, caster_loc, true)
	ParticleManager:SetParticleControlEnt(self.cast_fx, 2, caster, PATTACH_POINT_FOLLOW, nil, caster_loc, true)
	ParticleManager:SetParticleControlEnt(self.cast_fx, 4, caster, PATTACH_POINT_FOLLOW, nil, caster_loc, true)
	self:AddParticle(self.cast_fx, false, false, -1, false, false)
	if self.buff_fx then
		ParticleManager:DestroyParticle(self.buff_fx, false)
		ParticleManager:ReleaseParticleIndex(self.buff_fx)
	end
	self.buff_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_warcry_buff.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(self.buff_fx, 0, parent, PATTACH_POINT_FOLLOW, nil, parent:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(self.buff_fx, 1, parent, PATTACH_OVERHEAD_FOLLOW, nil, parent:GetAbsOrigin(), true)
	self:AddParticle(self.buff_fx, false, false, -1, false, false)
end

function modifier_imba_storm_bolt_talent_reduction:OnRefresh()
	self:OnCreated()
end

-------------------------------------------
modifier_imba_storm_bolt_caster = class({})
function modifier_imba_storm_bolt_caster:IsDebuff() return true end
function modifier_imba_storm_bolt_caster:IsHidden() return true end
function modifier_imba_storm_bolt_caster:IsPurgable() return false end
function modifier_imba_storm_bolt_caster:IsPurgeException() return false end
function modifier_imba_storm_bolt_caster:IsStunDebuff() return false end
function modifier_imba_storm_bolt_caster:RemoveOnDeath() return true end
-------------------------------------------

function modifier_imba_storm_bolt_caster:CheckState()
	local state =
	{
		[MODIFIER_STATE_STUNNED] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
	}
	return state
end

-------------------------------------------
modifier_imba_storm_bolt_crit = class({})
function modifier_imba_storm_bolt_crit:IsDebuff() return false end
function modifier_imba_storm_bolt_crit:IsHidden() return false end
function modifier_imba_storm_bolt_crit:IsPurgable() return false end
function modifier_imba_storm_bolt_crit:IsPurgeException() return true end
function modifier_imba_storm_bolt_crit:IsStunDebuff() return false end
function modifier_imba_storm_bolt_crit:RemoveOnDeath() return true end
-------------------------------------------

function modifier_imba_storm_bolt_crit:DeclareFunctions()
	local decFuns =
	{
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE
	}
	return decFuns
end

function modifier_imba_storm_bolt_crit:OnAttackLanded( params )
	if IsServer() then
		-- Destroy after first attack
		if self:GetParent() == params.attacker then
			self:Destroy()
		end
	end
end

function modifier_imba_storm_bolt_crit:GetModifierPreAttack_CriticalStrike( params )
	if self:GetAbility().target == params.target then
		return self:GetAbility():GetSpecialValueFor("crit_pct")
	else
		return nil
	end
end

-------------------------------------------
-- 				GREAT CLEAVE
-------------------------------------------
LinkLuaModifier("modifier_imba_great_cleave", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_great_cleave_active", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)

imba_sven_great_cleave = class({})
function imba_sven_great_cleave:IsHiddenWhenStolen() return false end
function imba_sven_great_cleave:IsRefreshable() return true end
function imba_sven_great_cleave:IsStealable() return true end
function imba_sven_great_cleave:IsNetherWardStealable() return false end

function imba_sven_great_cleave:GetAbilityTextureName()
   return "sven_great_cleave"
end
-------------------------------------------

function imba_sven_great_cleave:GetIntrinsicModifierName()
	return "modifier_imba_great_cleave"
end

function imba_sven_great_cleave:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		caster:AddNewModifier(caster, self, "modifier_imba_great_cleave_active", {duration = 5})
	end
end

-------------------------------------------
modifier_imba_great_cleave = class({})
function modifier_imba_great_cleave:IsDebuff() return false end
function modifier_imba_great_cleave:IsHidden() return true end
function modifier_imba_great_cleave:IsPurgable() return false end
function modifier_imba_great_cleave:IsPurgeException() return false end
function modifier_imba_great_cleave:IsStunDebuff() return false end
function modifier_imba_great_cleave:RemoveOnDeath() return true end
-------------------------------------------

function modifier_imba_great_cleave:DeclareFunctions()
	local decFuncs =
	{
		MODIFIER_EVENT_ON_ATTACK_LANDED
	}
	return decFuncs
end

function modifier_imba_great_cleave:OnAttackLanded( params )
	if IsServer() then
		local caster = self:GetCaster()
		local ability = self:GetAbility()
		if (params.attacker == caster) and caster:IsRealHero() and (params.target:GetTeamNumber() ~= caster:GetTeamNumber()) and (not caster:HasModifier("modifier_imba_great_cleave_active")) and not caster:PassivesDisabled() then
			local cleave_particle = "particles/units/heroes/hero_sven/sven_spell_great_cleave.vpcf"
			local cleave_damage_pct = ability:GetSpecialValueFor("great_cleave_damage") / 100
			local cleave_radius_start = ability:GetSpecialValueFor("cleave_starting_width")
			local cleave_radius_end = ability:GetTalentSpecialValueFor("cleave_ending_width")
			local cleave_distance = ability:GetTalentSpecialValueFor("cleave_distance")
			-- #4 Talent: Great Cleave cleaves at double the cleave values
			if caster:HasTalent("special_bonus_imba_sven_4") then
			cleave_particle = "particles/hero/sven/sven_spell_grand_cleave.vpcf"
			cleave_radius_start = cleave_radius_start * caster:FindTalentValue("special_bonus_imba_sven_4")
			cleave_radius_end = cleave_radius_end * caster:FindTalentValue("special_bonus_imba_sven_4")
			cleave_distance = cleave_distance * caster:FindTalentValue("special_bonus_imba_sven_4")
			end
			DoCleaveAttack( params.attacker, params.target, ability, (params.damage * cleave_damage_pct), cleave_radius_start, cleave_radius_end, cleave_distance, cleave_particle )
			-- #2 Talent: Great Cleave cleaves twice when the God's Strength is active
			if caster:HasTalent("special_bonus_imba_sven_1") and caster:HasModifier("modifier_imba_god_strength") then
				local cleave_particle_talent = "particles/hero/sven/sven_spell_great_cleave_gods_strength.vpcf"
				if caster:HasTalent("special_bonus_imba_sven_4") then
				cleave_particle_talent = "particles/hero/sven/sven_spell_grand_cleave_gods_strength.vpcf"
				end
				Timers:CreateTimer(caster:FindTalentValue("special_bonus_imba_sven_1"), function()
				if caster then
				DoCleaveAttack( params.attacker, params.target, ability, (params.damage * cleave_damage_pct), cleave_radius_start, cleave_radius_end, cleave_distance, cleave_particle_talent )
				end
				end)
			end
		end
	end
end

-------------------------------------------
modifier_imba_great_cleave_active = class({})
function modifier_imba_great_cleave_active:IsDebuff() return false end
function modifier_imba_great_cleave_active:IsHidden() return false end
function modifier_imba_great_cleave_active:IsPurgable() return false end
function modifier_imba_great_cleave_active:IsPurgeException() return false end
function modifier_imba_great_cleave_active:IsStunDebuff() return false end
function modifier_imba_great_cleave_active:RemoveOnDeath() return true end
-------------------------------------------

function modifier_imba_great_cleave_active:DeclareFunctions()
	local decFuncs =
	{
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
		MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE
	}
	return decFuncs
end

function modifier_imba_great_cleave_active:GetActivityTranslationModifiers()
	if self:GetParent():GetName() == "npc_dota_hero_sven" then
		return "fear"
	end
	return 0
end

function modifier_imba_great_cleave_active:CheckState()
	local state =
	{
		[MODIFIER_STATE_CANNOT_MISS] = true
	}
	return state
end

function modifier_imba_great_cleave_active:GetModifierTotalDamageOutgoing_Percentage( params ) 
	if IsServer() then
		if params.target and not params.inflictor then
			local armor = params.target:GetPhysicalArmorValue()
			local armor_ignore = self:GetAbility():GetTalentSpecialValueFor("armor_ignore")
			local reduction_feedback
			if armor < 0 then
				return 0
			elseif armor <= armor_ignore then
				reduction_feedback = CalculateReductionFromArmor_Percentage( 0, armor )
				
			else
				reduction_feedback = CalculateReductionFromArmor_Percentage( (armor - armor_ignore), armor )
			end
			reduction_feedback = reduction_feedback * (1 + ( reduction_feedback / 100))
			return reduction_feedback
		end
		return 0
	end
end

function modifier_imba_great_cleave_active:OnCreated()
	local parent = self:GetParent()
	local fire_fx = ParticleManager:CreateParticle("particles/hero/sven/great_cleave_glow_base.vpcf", PATTACH_ABSORIGIN, parent)
	ParticleManager:SetParticleControlEnt(fire_fx, 0, parent, PATTACH_POINT_FOLLOW, "attach_weapon", parent:GetAbsOrigin(), true)
	self:AddParticle(fire_fx, false, false, -1, false, false)
end

-------------------------------------------
--            WARCRY
-------------------------------------------
LinkLuaModifier("modifier_imba_warcry", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_warcry_immunity", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)

imba_sven_warcry = class({})
function imba_sven_warcry:IsHiddenWhenStolen() return false end
function imba_sven_warcry:IsRefreshable() return true end
function imba_sven_warcry:IsStealable() return true end
function imba_sven_warcry:IsPurgable() return true end
function imba_sven_warcry:IsNetherWardStealable() return true end

function imba_sven_warcry:GetAbilityTextureName()
   return "sven_warcry"
end
-------------------------------------------

function imba_sven_warcry:GetBehavior()
	-- #8 Talent: Allows WarCry to be activated while Sven is disabled
	local caster = self:GetCaster()
	if not caster:HasTalent("special_bonus_imba_sven_8") then
		return DOTA_ABILITY_BEHAVIOR_NO_TARGET + DOTA_ABILITY_BEHAVIOR_IMMEDIATE
	else
		return DOTA_ABILITY_BEHAVIOR_NO_TARGET + DOTA_ABILITY_BEHAVIOR_IMMEDIATE + DOTA_ABILITY_BEHAVIOR_IGNORE_PSEUDO_QUEUE
	end
end

function imba_sven_warcry:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		-- Parameters
		local ms_bonus_pct = self:GetTalentSpecialValueFor("ms_bonus_pct")
		local armor_bonus = self:GetSpecialValueFor("armor_bonus")
		local tenacity_bonus_pct = self:GetSpecialValueFor("tenacity_bonus_pct")
		local tenacity_self_pct = self:GetSpecialValueFor("tenacity_self_pct")
		local radius = self:GetSpecialValueFor("radius")
		local duration = self:GetSpecialValueFor("duration")

		local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, self:GetAbilityTargetTeam(), self:GetAbilityTargetType(), self:GetAbilityTargetFlags(), FIND_ANY_ORDER, false)
		for _,ally in ipairs(allies) do
			if caster == ally then
				caster:AddNewModifier(caster, self, "modifier_imba_warcry", {duration = duration})
				if caster:HasTalent("special_bonus_imba_sven_7") then
					caster:AddNewModifier(caster, self, "modifier_imba_warcry_immunity", {duration = caster:FindTalentValue("special_bonus_imba_sven_7")})
				end
			else
				ally:AddNewModifier(caster, self, "modifier_imba_warcry", {duration = duration})
			end
		end
		caster:StartGesture(ACT_DOTA_OVERRIDE_ABILITY_3)

	-- #8 Talent: Allows WarCry to be activated while Sven is disabled + apply strong purge
		if caster:HasTalent("special_bonus_imba_sven_8") then
		caster:Purge(false, true, false, true, true) --don't remove buffs, remove debuffs, not only on this frame, purges stuns.
		else
		-- Else Apply normal purge
		caster:Purge(false,true,false,false,false)
		end
	end
end

function imba_sven_warcry:GetCastRange( location , target)
	return self:GetSpecialValueFor("radius")
end

-------------------------------------------
modifier_imba_warcry = class({})
function modifier_imba_warcry:IsDebuff() return false end
function modifier_imba_warcry:IsHidden() return false end
function modifier_imba_warcry:IsPurgable() return true end
function modifier_imba_warcry:IsStunDebuff() return false end
function modifier_imba_warcry:RemoveOnDeath() return true end
-------------------------------------------

function modifier_imba_warcry:DeclareFunctions()
	local decFuns =
	{
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS
	}
	return decFuns
end

function modifier_imba_warcry:GetActivityTranslationModifiers()
	if self:GetParent():GetName() == "npc_dota_hero_sven" then
		return "sven_warcry"
	end
	return 0
end

function modifier_imba_warcry:OnCreated()
	local ability = self:GetAbility()
	local caster = self:GetCaster()
	local parent = self:GetParent()
	
	self.ms_bonus_pct = ability:GetTalentSpecialValueFor("ms_bonus_pct")
	self.armor_bonus = ability:GetSpecialValueFor("armor_bonus")
	if parent == caster then
		if IsServer() then
			caster:EmitSound("Hero_Sven.WarCry")
			if caster:GetName() == "npc_dota_hero_sven" then
				caster:EmitSound("sven_sven_ability_warcry_0"..math.random(1,6))
			end
		end
		local caster_loc = caster:GetAbsOrigin()
		self.tenacity_pct = ability:GetSpecialValueFor("tenacity_self_pct")
		if self.cast_fx then
			ParticleManager:DestroyParticle(self.cast_fx, false)
			ParticleManager:ReleaseParticleIndex(self.cast_fx)
		end
		self.cast_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_spell_warcry.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
		ParticleManager:SetParticleControlEnt(self.cast_fx, 0, caster, PATTACH_POINT_FOLLOW, nil, caster_loc, true)
		ParticleManager:SetParticleControlEnt(self.cast_fx, 1, caster, PATTACH_POINT_FOLLOW, nil, caster_loc, true)
		ParticleManager:SetParticleControlEnt(self.cast_fx, 2, caster, PATTACH_POINT_FOLLOW, nil, caster_loc, true)
		ParticleManager:SetParticleControlEnt(self.cast_fx, 4, caster, PATTACH_POINT_FOLLOW, nil, caster_loc, true)
		self:AddParticle(self.cast_fx, false, false, -1, false, false)
	else
		self.tenacity_pct = ability:GetSpecialValueFor("tenacity_bonus_pct")
	end
	if self.buff_fx then
		ParticleManager:DestroyParticle(self.buff_fx, false)
		ParticleManager:ReleaseParticleIndex(self.buff_fx)
	end
	self.buff_fx = ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_warcry_buff.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(self.buff_fx, 0, parent, PATTACH_POINT_FOLLOW, nil, parent:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(self.buff_fx, 1, parent, PATTACH_OVERHEAD_FOLLOW, nil, parent:GetAbsOrigin(), true)
	self:AddParticle(self.buff_fx, false, false, -1, false, false)
end

function modifier_imba_warcry:OnRefresh()
	self:OnCreated()
end

function modifier_imba_warcry:GetCustomTenacity()
	return self.tenacity_pct
end

function modifier_imba_warcry:GetModifierMoveSpeedBonus_Percentage()
	return self.ms_bonus_pct
end

function modifier_imba_warcry:GetModifierPhysicalArmorBonus()
	return self.armor_bonus
end

-------------------------------------------
modifier_imba_warcry_immunity = class({})
function modifier_imba_warcry_immunity:IsDebuff() return false end
function modifier_imba_warcry_immunity:IsHidden() return false end
function modifier_imba_warcry_immunity:IsPurgable() return true end
function modifier_imba_warcry_immunity:IsStunDebuff() return false end
function modifier_imba_warcry_immunity:RemoveOnDeath() return true end
-------------------------------------------
function modifier_imba_warcry_immunity:CheckState()
	local state =
	{
		[MODIFIER_STATE_MAGIC_IMMUNE] = true
	}
	return state
end

function modifier_imba_warcry_immunity:GetEffectName()
	return "particles/items_fx/black_king_bar_avatar.vpcf"
end

function modifier_imba_warcry_immunity:GetEffectAttachType()
	return PATTACH_POINT_FOLLOW
end

-------------------------------------------
--			GOD'S STRENGTH
-------------------------------------------
LinkLuaModifier("modifier_imba_god_strength", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_god_strength_allies", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)

imba_sven_gods_strength = class({})
function imba_sven_gods_strength:IsHiddenWhenStolen() return false end
function imba_sven_gods_strength:IsRefreshable() return true end
function imba_sven_gods_strength:IsStealable() return true end
function imba_sven_gods_strength:IsNetherWardStealable() return false end

function imba_sven_gods_strength:GetAbilityTextureName()
   return "sven_gods_strength"
end
-------------------------------------------
function imba_sven_gods_strength:GetCooldown( nLevel )
	return self.BaseClass.GetCooldown( self, nLevel )
end

function imba_sven_gods_strength:GetAssociatedSecondaryAbilities()
	return "imba_sven_colossal_slash"
end

function imba_sven_gods_strength:OnUpgrade()
	if IsServer() then
		local caster = self:GetCaster()
		local ability_slash = caster:FindAbilityByName(self:GetAssociatedSecondaryAbilities())
		ability_slash:SetLevel(self:GetLevel())
		if not caster:HasModifier("modifier_imba_god_strength") then
			ability_slash:SetActivated(false)
		end
	end
end

function imba_sven_gods_strength:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		local duration = self:GetSpecialValueFor("duration")
		caster:AddNewModifier(caster, self, "modifier_imba_god_strength", {duration = duration})
		caster:EmitSound("Hero_Sven.GodsStrength")
		if (math.random(1,100) <= 25) then
			caster:EmitSound("Imba.SvenBeAMan")
		end
		caster:StartGesture(ACT_DOTA_OVERRIDE_ABILITY_4)
		
		local roar_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_spell_gods_strength.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
		ParticleManager:SetParticleControlEnt(roar_pfx, 1, caster, PATTACH_ABSORIGIN_FOLLOW, nil, caster:GetAbsOrigin(), true)
		ParticleManager:ReleaseParticleIndex(roar_pfx)
	end
end
-------------------------------------------
modifier_imba_god_strength = class({})
function modifier_imba_god_strength:IsDebuff() return false end
function modifier_imba_god_strength:IsHidden() return false end
function modifier_imba_god_strength:IsPurgable() return false end
function modifier_imba_god_strength:IsPurgeException() return false end
function modifier_imba_god_strength:IsStunDebuff() return false end
function modifier_imba_god_strength:RemoveOnDeath() return true end
-------------------------------------------

function modifier_imba_god_strength:IsAura()
	if IsServer() then
		return self:GetCaster():HasScepter()
	end
	return false
end

function modifier_imba_god_strength:GetAttackSound()
	return "Hero_Sven.GodsStrength.Attack"
end

function modifier_imba_god_strength:DeclareFunctions()
	local decFuncs = 
	{
		MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
		MODIFIER_PROPERTY_TRANSLATE_ATTACK_SOUND
	}
	return decFuncs
end

function modifier_imba_god_strength:GetHeroEffectName()
	return "particles/units/heroes/hero_sven/sven_gods_strength_hero_effect.vpcf"
end

function modifier_imba_god_strength:HeroEffectPriority()
	return 10
end

function modifier_imba_god_strength:GetStatusEffectName()
	return "particles/status_fx/status_effect_gods_strength.vpcf"
end

function modifier_imba_god_strength:StatusEffectPriority()
	return 10
end

function modifier_imba_god_strength:GetAuraSearchTeam()
	return self:GetAbility():GetAbilityTargetTeam()
end

function modifier_imba_god_strength:GetAuraSearchType()
	return self:GetAbility():GetAbilityTargetType()
end

function modifier_imba_god_strength:GetModifierAura()
	return "modifier_imba_god_strength_allies"
end

function modifier_imba_god_strength:GetAuraSearchFlags()
	return self:GetAbility():GetAbilityTargetFlags()
end

function modifier_imba_god_strength:GetAuraRadius()
	return self.aura_radius_scepter
end

function modifier_imba_god_strength:GetAuraEntityReject( target )
	if IsServer() then
		if self:GetParent() == target then
			return true
		end
	end
	return false
end

function modifier_imba_god_strength:GetModifierBaseDamageOutgoing_Percentage()
	return self.bonus_dmg_pct
end

function modifier_imba_god_strength:OnCreated()
	self.bonus_dmg_pct = self:GetAbility():GetTalentSpecialValueFor("bonus_dmg_pct")
	self.aura_radius_scepter = self:GetAbility():GetSpecialValueFor("aura_radius_scepter")

	if IsServer() then
		local nFXIndex = ParticleManager:CreateParticle( "particles/units/heroes/hero_sven/sven_spell_gods_strength_ambient.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent() )
		ParticleManager:SetParticleControlEnt( nFXIndex, 0, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_weapon" , self:GetParent():GetOrigin(), true )
		ParticleManager:SetParticleControlEnt( nFXIndex, 2, self:GetParent(), PATTACH_POINT_FOLLOW, "attach_head" , self:GetParent():GetOrigin(), true )
		self:AddParticle( nFXIndex, false, false, -1, false, true )
		self:GetCaster():FindAbilityByName("imba_sven_colossal_slash"):SetActivated(true)
	end
end

function modifier_imba_god_strength:OnRefresh()
	self.bonus_dmg_pct = self:GetAbility():GetSpecialValueFor("gods_strength_damage")
	self.aura_radius_scepter = self:GetAbility():GetSpecialValueFor("aura_radius_scepter")
end

function modifier_imba_god_strength:OnDestroy()
	if IsServer() then
		self:GetCaster():FindAbilityByName("imba_sven_colossal_slash"):SetActivated(false)
	end
end

-------------------------------------------
modifier_imba_god_strength_allies = class({})
function modifier_imba_god_strength_allies:IsDebuff() return false end
function modifier_imba_god_strength_allies:IsHidden() return false end
function modifier_imba_god_strength_allies:IsPurgable() return false end
function modifier_imba_god_strength_allies:IsPurgeException() return false end
function modifier_imba_god_strength_allies:IsStunDebuff() return false end
function modifier_imba_god_strength_allies:RemoveOnDeath() return true end
-------------------------------------------
function modifier_imba_god_strength_allies:GetModifierBaseDamageOutgoing_Percentage()
	return self.bonus_dmg_pct
end

function modifier_imba_god_strength_allies:OnCreated()
	self.bonus_dmg_pct = self:GetAbility():GetSpecialValueFor("ally_bonus_dmg_pct_scepter")
end

function modifier_imba_god_strength_allies:OnRefresh()
	self:OnCreated()
end

function modifier_imba_god_strength_allies:DeclareFunctions()
	local decFuncs = 
	{
		MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
	}
	return decFuncs
end
-------------------------------------------
--			COLOSSAL SLASH
-------------------------------------------
LinkLuaModifier("modifier_imba_colossal_slash_animation", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_colossal_slash_crit", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_imba_colossal_slash_talent_pierce", "hero/hero_sven", LUA_MODIFIER_MOTION_NONE)
imba_sven_colossal_slash = class({})
function imba_sven_colossal_slash:IsHiddenWhenStolen() return false end
function imba_sven_colossal_slash:IsRefreshable() return true end
function imba_sven_colossal_slash:IsStealable() return true end
function imba_sven_colossal_slash:IsNetherWardStealable() return false end

function imba_sven_colossal_slash:GetAbilityTextureName()
   return "custom/sven_colossal_strike"
end
-------------------------------------------

function imba_sven_colossal_slash:GetAssociatedPrimaryAbilities()
	return "imba_sven_gods_strength"
end

function imba_sven_colossal_slash:OnAbilityPhaseStart()
	local caster = self:GetCaster()
	self.animation = true
	local roar_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_sven/sven_spell_gods_strength.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(roar_pfx, 1, caster, PATTACH_ABSORIGIN_FOLLOW, nil, caster:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(roar_pfx)
	
	if caster:GetName() == "npc_dota_hero_sven" then
		-- Randomly play a cast line
		if (math.random(1,100) <= 25) then
			self.sound = "Imba.SvenGetsugaTensho"
		else
			self.sound = "sven_sven_ability_godstrength_0"..math.random(1,2)
		end
		caster:EmitSound(self.sound)
		self.swing_fx = ParticleManager:CreateParticle("particles/hero/sven/colossal_slash_cast.vpcf", PATTACH_CUSTOMORIGIN_FOLLOW, caster)
		local swing_fx = self.swing_fx
		ParticleManager:SetParticleControlEnt(self.swing_fx, 0, caster, PATTACH_POINT_FOLLOW, "attach_sword", caster:GetAbsOrigin(), true)
		ParticleManager:SetParticleControlEnt(self.swing_fx, 1, caster, PATTACH_POINT_FOLLOW, "attach_sword", caster:GetAbsOrigin(), true)
		Timers:CreateTimer(self:GetBackswingTime(), function()
			ParticleManager:DestroyParticle(swing_fx, false)
			ParticleManager:ReleaseParticleIndex(swing_fx)
		end)
		--caster:FadeGesture(ACT_DOTA_OVERRIDE_ABILITY_3)
		--caster:FadeGesture(ACT_DOTA_OVERRIDE_ABILITY_4)
		caster:StartGestureWithPlaybackRate(ACT_DOTA_VICTORY,3)
		Timers:CreateTimer(0.4, function()
			if self.animation then
				local mod = caster:AddNewModifier(caster, self, "modifier_imba_colossal_slash_animation", {})
				caster:FadeGesture(ACT_DOTA_VICTORY)
				caster:StartGestureWithPlaybackRate(ACT_DOTA_SPAWN,1.4)
				Timers:CreateTimer(FrameTime(), function()
					mod:Destroy()
				end)
			end
		end)
	end
	return true
end

function imba_sven_colossal_slash:OnAbilityPhaseInterrupted()
	if IsServer() then
		local caster = self:GetCaster()
		caster:FadeGesture(ACT_DOTA_VICTORY)
		caster:FadeGesture(ACT_DOTA_SPAWN)
		self.animation = false
		if self.sound then
			caster:StopSound(self.sound)
		end
		ParticleManager:DestroyParticle(self.swing_fx, false)
		return true
	end
end

function imba_sven_colossal_slash:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		local target_loc = self:GetCursorPosition()
		local caster_loc = caster:GetAbsOrigin()

		-- Parameters
		local proj_speed = self:GetSpecialValueFor("proj_speed")
		local radius = self:GetSpecialValueFor("radius")
		local start_radius = self:GetSpecialValueFor("start_radius")
		local end_radius = self:GetSpecialValueFor("end_radius")
		local crit_bonus_pct = self:GetSpecialValueFor("crit_bonus_pct")
		local base_range = self:GetSpecialValueFor("base_range")
		local range_multiplier = self:GetSpecialValueFor("range_multiplier")
		local direction = (target_loc - caster_loc):Normalized()
		
		local modifier = caster:FindModifierByName("modifier_imba_god_strength")
		local gods_strength_ability = caster:FindAbilityByName("imba_sven_gods_strength")
		ScreenShake(caster_loc, 10, 0.3, 0.5, 1000, 0, true)
		local remaining_time = 0
		if modifier then
			remaining_time = modifier:GetRemainingTime()
			modifier:Destroy()
		end

		local total_range = base_range + (remaining_time * range_multiplier)

		--local caster_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_earth_spirit/espirit_spawn_ground.vpcf", PATTACH_ABSORIGIN, caster)
		--ParticleManager:SetParticleControl(caster_pfx, 0, (caster:GetAbsOrigin() + direction*100))
		
		-- Launch projectile
		local projectile =
		{
			Ability				= self,
			EffectName			= "particles/hero/sven/colossal_slash_new.vpcf",
			vSpawnOrigin		= caster_loc,
			fDistance			= total_range,
			fStartRadius		= start_radius,
			fEndRadius			= end_radius,
			Source				= caster,
			bHasFrontalCone		= false,
			bReplaceExisting	= false,
			iUnitTargetTeam		= DOTA_UNIT_TARGET_TEAM_ENEMY,
			iUnitTargetType		= DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			fExpireTime 		= GameRules:GetGameTime() + 5.0,
			bDeleteOnHit		= false,
			vVelocity			= Vector(direction.x,direction.y,0) * proj_speed,
			bProvidesVision		= true,
			iVisionRadius 		= radius,
			iVisionTeamNumber 	= caster:GetTeamNumber(),
			ExtraData			= {remaining_time = remaining_time}
		}
		ProjectileManager:CreateLinearProjectile(projectile)

		EmitSoundOnLocationWithCaster(caster_loc, "Imba.SvenShockWave", caster)
		local current_distance = 0
		local rate = 0.3
		-- Provide vision along the projectile's path
		Timers:CreateTimer(0, function()
			local location = caster_loc + direction * current_distance
			current_distance = current_distance + (proj_speed * rate)
			if current_distance < total_range then
				return rate
			end
		end)
	end
end

function imba_sven_colossal_slash:OnProjectileHit_ExtraData(target, location, ExtraData)
	if target then
		local caster = self:GetCaster()
		local talent_mod = target:FindModifierByName("modifier_imba_colossal_slash_talent_pierce")
		-- #5 Talent: Colossal Slash penetrates a portion of the target's armor.
		if caster:HasTalent("special_bonus_imba_sven_5") and (not talent_mod) then
			local talent_modifier = target:AddNewModifier(caster, self, "modifier_imba_colossal_slash_talent_pierce", {})
			-- Get the remaining duration of God's Strength
			if talent_modifier then
				talent_modifier.remaining_time = math.floor(ExtraData.remaining_time)
			end
		end
		-- Add the crit modifier
		local mod = caster:AddNewModifier(caster, self, "modifier_imba_colossal_slash_crit", {})
		-- Attack on target
		caster:PerformAttack(target, true, false, true, true, true, false, true)
		-- After the attack, destroy both modifiers
		mod:Destroy()
	end
end
-------------------------------------------
modifier_imba_colossal_slash_crit = class({})
function modifier_imba_colossal_slash_crit:IsDebuff() return false end
function modifier_imba_colossal_slash_crit:IsHidden() return true end
function modifier_imba_colossal_slash_crit:IsPurgable() return false end
function modifier_imba_colossal_slash_crit:IsPurgeException() return false end
function modifier_imba_colossal_slash_crit:IsStunDebuff() return false end
function modifier_imba_colossal_slash_crit:RemoveOnDeath() return true end
-------------------------------------------
function modifier_imba_colossal_slash_crit:DeclareFunctions()
	local decFuncs = 
	{
		MODIFIER_PROPERTY_BASEDAMAGEOUTGOING_PERCENTAGE,
		MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
		MODIFIER_PROPERTY_TRANSLATE_ATTACK_SOUND,
		MODIFIER_EVENT_ON_HERO_KILLED,
	}
	return decFuncs
end

function modifier_imba_colossal_slash_crit:GetAttackSound()
	return "Hero_Sven.GodsStrength.Attack"
end

function modifier_imba_colossal_slash_crit:OnCreated()
	self.crit_bonus_pct = self:GetAbility():GetSpecialValueFor("crit_bonus_pct") - 100
	if self:GetCaster():HasModifier("modifier_imba_god_strength") then
		self.bonus_dmg_pct = 0
	else
		self.bonus_dmg_pct = self:GetAbility():GetTalentSpecialValueFor("bonus_dmg_pct")
	end
end

function modifier_imba_colossal_slash_crit:GetModifierBaseDamageOutgoing_Percentage()
	return self.bonus_dmg_pct
end

function modifier_imba_colossal_slash_crit:GetModifierTotalDamageOutgoing_Percentage(params)
	local damage = params.damage + (params.damage * self.crit_bonus_pct / 100)
	SendOverheadEventMessage(nil, OVERHEAD_ALERT_CRITICAL, params.target, damage, nil)
	return self.crit_bonus_pct
end

-- #1 Talent: God's Strength Cooldown reduced by 20% for each Colossal Slash hero kill.
function modifier_imba_colossal_slash_crit:OnHeroKilled(params)
	if IsServer() then
		local caster = self:GetCaster()
		local attacker = params.attacker
		if attacker == caster and caster:HasTalent("special_bonus_imba_sven_2") then
			local god_strength_ability = caster:FindAbilityByName("imba_sven_gods_strength")
			if god_strength_ability then
				local current_cooldown = god_strength_ability:GetCooldownTimeRemaining()
				god_strength_ability:EndCooldown()
				god_strength_ability:StartCooldown(current_cooldown - (current_cooldown * caster:FindTalentValue("special_bonus_imba_sven_2") * 0.01))
			end
		end
	end
end

-- #5 Talent: Colossal Slash penetrates a portion of the target's armor.
-------------------------------------------
modifier_imba_colossal_slash_talent_pierce = class({})
function modifier_imba_colossal_slash_talent_pierce:IsDebuff() return false end
function modifier_imba_colossal_slash_talent_pierce:IsHidden() return true end
function modifier_imba_colossal_slash_talent_pierce:IsPurgable() return false end
function modifier_imba_colossal_slash_talent_pierce:IsPurgeException() return false end
function modifier_imba_colossal_slash_talent_pierce:IsStunDebuff() return false end
function modifier_imba_colossal_slash_talent_pierce:RemoveOnDeath() return true end
-------------------------------------------
function modifier_imba_colossal_slash_talent_pierce:DeclareFunctions()
	local decFuncs = 
	{
		MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS
	}
	return decFuncs
end

function modifier_imba_colossal_slash_talent_pierce:GetModifierPhysicalArmorBonus()
	if self.remaining_time then
	return self:GetCaster():FindTalentValue("special_bonus_imba_sven_5") * (-1) * self.remaining_time
	else
	return 0
	end
end

-- Create the particle effects
function modifier_imba_colossal_slash_talent_pierce:OnCreated()
	if IsServer() then
		-- Destroys itself after an instance
		self:Destroy()
	end
end
-------------------------------------------
modifier_imba_colossal_slash_animation = class({})
function modifier_imba_colossal_slash_animation:IsDebuff() return false end
function modifier_imba_colossal_slash_animation:IsHidden() return false end
function modifier_imba_colossal_slash_animation:IsPurgable() return false end
function modifier_imba_colossal_slash_animation:IsPurgeException() return false end
function modifier_imba_colossal_slash_animation:IsStunDebuff() return false end
function modifier_imba_colossal_slash_animation:RemoveOnDeath() return true end
-------------------------------------------

function modifier_imba_colossal_slash_animation:DeclareFunctions()
	local decFuns =
	{
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
	}
	return decFuns
end

function modifier_imba_colossal_slash_animation:GetActivityTranslationModifiers()
	if self:GetParent():GetName() == "npc_dota_hero_sven" then
		return "loadout"
	end
	return 0
end
