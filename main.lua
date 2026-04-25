#version 2

--This script will run on all levels when mod is active.
--Modding documentation: http://teardowngame.com/modding
--API reference: http://teardowngame.com/modding/api.html

function server.GetLocalPlayer(player)
    ServerLocalPlayer = player
end

function server.init()
end

function server.tick(delta)
    PlayerVelocity = GetEvent("PlayerVelocity",1)
    JumpKitCall = GetEvent("JumpKitCall",1)
    SlideBoostCall = GetEvent("SlideBoostCall",1)
    SlideCall = GetEvent("SlideCall",1)
    PreserveAirMomentumCall = GetEvent("PreserveAirMomentumCall",1)
    PreventFallDamageCall = GetEvent("PreventFallDamageCall",1)
    if JumpKitCall then
        server.playerJumpKit()
    end
    if SlideBoostCall then
        server.playerSlideBoost()
    end
    if SlideCall then
        server.playerSlide()
    end
    if PreserveAirMomentumCall then
        server.playerPreserveAirMomentum()
    end
    if PreventFallDamageCall then
        server.playerPreventFallDamage()
    end
end

function server.update(delta)
end

function client.init()
    client.player_controller_init()
end

function client.tick(delta)
    client.player_controller_tick()
end

function client.render(delta)
    client.player_controller_render(delta)
end

function client.update(delta)
    client.player_controller_update(delta)
end

function client.postUpdate()
    client.player_controller_postUpdate()
end

function client.draw()
end


function client.player_controller_init()
    Purple = {r=0.5,g=0,b=0.5,a=1}
    Pink = {r=1,g=0,b=1,a=1}
    Yellow = {r=1,g=1,b=0,a=1}
    Red = {r=1,g=0,b=0,a=1}
    LightBlue = {r=0.1,g=0.1,b=1,a=1}
    LightGreen = {r=0.1,g=1,b=0.1,a=1}
    Orange = {r=1,g=0.5,b=0,a=1}

    LocalPlayer = GetLocalPlayer()
    ServerCall("server.GetLocalPlayer", LocalPlayer)
end
function client.player_controller_render(delta)
    local pos = SelectedTransform.pos

    DebugCross(pos, Purple.r, Purple.g, Purple.b, 1)

    DebugLine(pos, LookDirection, Yellow.r, Yellow.g, Yellow.b, 1)
    DebugCross(LookDirection, Yellow.r, Yellow.g, Yellow.b, 1)
    DebugLine(pos, LeftDirection, Red.r, Red.g, Red.b, 1)
    DebugCross(LeftDirection, Red.r, Red.g, Red.b, 1)
    DebugLine(pos, RightDirection, LightBlue.r, LightBlue.g, LightBlue.b, 1)
    DebugCross(RightDirection, LightBlue.r, LightBlue.g, LightBlue.b, 1)
    DebugLine(pos, BackDirection, LightGreen.r, LightGreen.g, LightGreen.b, 1)

    DebugCross(CastHitPosition, Pink.r, Pink.g, Pink.b, 1)
    DebugLine(CastHitPosition, CastHitNormal, Pink.r, Pink.g, Pink.b, 1)
end
function client.player_controller_draw()
end
function client.player_controller_update(delta)
end
function client.player_controller_postUpdate()
end
function client.player_controller_tick(delta)
    DeltaTick = GetTimeStep()
    PlayerVelocity = GetPlayerVelocity(0)
    PostEvent("PlayerVelocity",PlayerVelocity)

    FallCheck() --Attempt to basically disable fall damage
    JumpKit() --Double jump, includes coyote jumping and velocity changes on air jumps
    Sliding() --Basic sliding, plus the slide boost with a two-second cooldown
    LookForWalls() --Wallrunning
end

function LookForWalls()
    LookDistance = 5
    OriginOffset = 1 - (GetPlayerCrouch(0)/2)
    EyeTransform = GetPlayerEyeTransform(0)
    PlayerTransform = GetPlayerTransform(0)
    SelectedTransform = PlayerTransform
    SelectedTransform = Transform(Vec(SelectedTransform.pos[1], SelectedTransform.pos[2] + OriginOffset, SelectedTransform.pos[3]), SelectedTransform.rot)

    IsOccupied = 0 --Whether or not player is occupied with a current shape
    CurrentOccupant = 0
    Forward = Vec(0, 0, -LookDistance)
    Left = Vec(LookDistance, 0, 0)
    Right = Vec(-LookDistance, 0, 0)
    Back = Vec(0, 0, LookDistance)
    LookDirection = TransformToParentPoint(SelectedTransform, Forward)
    LeftDirection = TransformToParentPoint(SelectedTransform, Left)
    RightDirection = TransformToParentPoint(SelectedTransform, Right)
    BackDirection = TransformToParentPoint(SelectedTransform, Back)
    CastDirections = {Forward,Left,Right,Back}
    CastInfo = {hit=false, distance=0, normal=Vec(0,0,0), shape=0}
    CastDirection = Vec(0,0,0)
    CastHitPosition = Vec(0,0,0)
    CastHitNormal = Vec(0,0,0)

    for i = 1, table.maxn(CastDirections), 1 do
        CastInfo.hit,CastInfo.distance,CastInfo.normal,CastInfo.shape = QueryRaycast(SelectedTransform.pos, CastDirections[i], LookDistance, 0, false)
        if CastInfo.hit == true then
            CastDirection = CastDirections[i]
        else
            CastDirection = Vec(0,0,0)
        end
    end
    if CastInfo.hit == true then
        CastHitPosition = (VecAdd(SelectedTransform.pos, VecScale(CastDirection, CastInfo.distance)))
        CastHitNormal = (VecAdd(CastHitPosition, CastInfo.normal))
    else
        CastHitPosition = Vec(0,0,0)
        CastHitNormal = Vec(0,0,0)
    end

    DebugWatch("CastInfo",CastInfo,false)
    DebugWatch("CastDirection",CastDirection,false)
    DebugWatch("CastHitPosition",CastHitPosition,false)
end

JumpKitCall = false
JumpState = 0
MaxAirJumps = 1
AirJumps = 0
JumpBufferMax = 0.125
JumpBuffer = 0.0
JumpVelocity = 6
PreForceDir = Vec(0,0,0)
Force = 0
ForceDir = Vec(0,0,0)
ForceDirection = Vec(0,0,0)
ForceMultiplierDefault = 6
ForceMultiplier = Vec(ForceMultiplierDefault, 0, ForceMultiplierDefault)
function JumpKit()
    Up = GetPlayerUp(0)
    local playerVelocityLengthXZ = VecLength(Vec(PlayerVelocity[1],0,PlayerVelocity[3]))
    local eyeTransform = GetPlayerEyeTransform(0)
    local playerTransform = GetPlayerTransform(0)
    local baseTransform = Transform(Vec(0,0,0),playerTransform.rot)

    if InputDown("up",0) or InputDown("down",0) or InputDown("left",0) or InputDown("right",0) then
        Force = 1
    else
        Force = 0
    end
    if InputValue("up", 0) > 0 and InputValue("down", 0) == 0 then
        PreForceDir[3] = -InputValue("up", 0)
    elseif InputValue("down", 0) > 0 and InputValue("up", 0) == 0 then
        PreForceDir[3] = InputValue("down", 0)
    else
        PreForceDir[3] = 0
    end
    if InputValue("left", 0) > 0 and InputValue("right", 0) == 0 then
        PreForceDir[1] = -InputValue("left", 0)
    elseif InputValue("right", 0) > 0 and InputValue("left", 0) == 0 then
        PreForceDir[1] = InputValue("right", 0)
    else
        PreForceDir[1] = 0
    end
    for i = 0, table.maxn(PreForceDir) do
        if PreForceDir[i] then
            if i ~= 2 then
                if PreForceDir[i] > 1 then
                    PreForceDir[i] = 1
                elseif PreForceDir[i] < -1 then
                    PreForceDir[i] = -1
                end
            end
        end
    end
    ForceDirection = TransformToParentPoint(baseTransform,PreForceDir)
    -- if VecLength(PreForceDir) > 1 then
    --     PreForceDir = VecNormalize(ForceDir)
    -- end
    if PreForceDir[2] ~= 0.0 then
        PreForceDir[2] = 0.0
    end
    ForceDir = Vec(0,0,0)
    -- DebugWatch("X Velocity", playerVelocity[1], false)
    -- DebugWatch("Z Velocity", playerVelocity[3], false)
    -- DebugWatch("XZ Velocity Length", playerVelocityLengthXZ, false)
    for i = 0, table.maxn(ForceMultiplier), 1 do
        if ForceMultiplier[i] then
            if i ~= 2 then
                if PlayerVelocity[i] > 0 then
                    if ForceDirection[i] > 0 then
                        if playerVelocityLengthXZ > ForceMultiplierDefault+1 then
                            ForceMultiplier[i] = 0
                            Force = 0
                        else
                            ForceMultiplier[i] = ForceMultiplierDefault
                        end
                    else
                        ForceMultiplier[i] = ForceMultiplierDefault
                    end
                elseif PlayerVelocity[i] < 0 then
                    if ForceDirection[i] < 0 then
                        if playerVelocityLengthXZ > ForceMultiplierDefault+1 then
                            ForceMultiplier[i] = 0
                            Force = 0
                        else
                            ForceMultiplier[i] = ForceMultiplierDefault
                        end
                    else
                        ForceMultiplier[i] = ForceMultiplierDefault
                    end
                end
            end
        end
    end
    -- ForceDir = VecScale(ForceDirection, ForceMultiplier)
    ForceDir[1] = ForceDirection[1] * ForceMultiplier[1]
    ForceDir[3] = ForceDirection[3] * ForceMultiplier[3]
    -- DebugLine(playerTransform.pos, VecAdd(playerTransform.pos,ForceDir), Orange.r, Orange.g, Orange.b, 1)

    if IsPlayerGrounded(0) == true then
        AirJumps = MaxAirJumps
        if JumpState >= 3 then
            JumpState = 0
        end
        JumpBuffer = JumpBufferMax
    else
        if JumpState == 0 then
            if JumpBuffer > 0.0 then
                JumpBuffer = JumpBuffer - DeltaTick
            end
        end
        if JumpBuffer <= 0.0 then
            if JumpBuffer ~= -1.0 then
                JumpBuffer = -1.0
            end
    end
    end
    if InputPressed("jump", 0) then
        if JumpState == 0 or JumpState == 4 then
            JumpState = 1
        end
        if JumpBuffer == -1.0 then
            if JumpState ~= 3 then
                JumpState = 1
                JumpBuffer = 0.0
            end
        end
    end
    if InputReleased("jump", 0) then
        if JumpState == 2 then
            if AirJumps > 0 then
                JumpState = 4
            else
                JumpState = 3
            end
        end
    end
    if AirJumps > 0 then
        if JumpState == 1 then
            if IsPlayerJumping(0) == true or IsPlayerGrounded(0) == false then
                if IsPlayerJumping(0) == true then
                    ForceDir = Vec(0,0,0)
                    Force = 0
                end
                if JumpBuffer < JumpBufferMax and JumpBuffer > 0.0 then
                    ForceDir = Vec(0,0,0)
                    Force = 0
                end
                JumpKitCall = true
                PostEvent("JumpKitCall",JumpKitCall)
                if IsPlayerGrounded(0) == false then
                    AirJumps = AirJumps - 1
                    if JumpBuffer > 0.0 and JumpBuffer ~= JumpBufferMax then
                        AirJumps = AirJumps + 1
                        JumpBuffer = -1.0
                    end
                end
                JumpState = 2
            end
        end
    end
    PostEvent("ForceDir",ForceDir)
    PostEvent("Force",Force)
    -- DebugWatch("AirJumps",AirJumps,false)
    -- DebugWatch("JumpBuffer",JumpBuffer,false)
    -- DebugWatch("JumpState",JumpState,false)
    -- DebugWatch("ForceDir",ForceDir,false)
end
function server.playerJumpKit()
    JumpKitCall = false
    ForceDir = GetEvent("ForceDir",1)
    Force = GetEvent("Force",1)
    local newVelocity = Vec((PlayerVelocity[1]*-(Force-1)) + ForceDir[1], (PlayerVelocity[2]*AirJumps) + (JumpVelocity+(AirJumps*5)), (PlayerVelocity[3]*-(Force-1)) + ForceDir[3])
    SetPlayerVelocity(newVelocity, ServerLocalPlayer)
    -- DebugWatch("server.ForceDir",ForceDir,false)
    -- DebugWatch("","Applying Jumpkit boost...",false)
end

SlideBoostCall = false
SlideCall = false
PreserveAirMomentumCall = false
MinimumCrouchDefault = 0.01
MinimumCrouch = MinimumCrouchDefault
CrouchResetThresholdDefault = MinimumCrouch*0.9
CrouchResetThreshold = CrouchResetThresholdDefault
FullCrouch = 0.9
CanSlideBoost = false
CanSlide = false
SlideBoostCooldownMax = 2.0
SlideBoostCooldown = SlideBoostCooldownMax
SlideBoostReady = 0
SlideBoostMultiplier = 1.1
SlideBoostInputMultiplier = 0
IsSliding = false
SlideVelocity = Vec(0,0,0)
SlideVelocityDecayMultiplier = 0.995
AirMomentumMultiplier = 1.05
SlideCallFrequencyMax = 0.1
SlideCallFrequency = SlideCallFrequencyMax
function Sliding()
    SlideBoostInputMultiplier = InputValue("up",0)
    PostEvent("SlideBoostInputMultiplier",SlideBoostInputMultiplier)
    local crouch = GetPlayerCrouch(0)
    local grounded = IsPlayerGrounded(0)

    if InputValue("up",0) > 0 then
        if SlideBoostReady ~= 2 then
            SlideBoostReady = 1
        end
    else
        if SlideBoostReady ~= 2 then
            SlideBoostReady = 0
        end
    end
    if SlideBoostReady == 2 then
        MinimumCrouch = 0.5
        CrouchResetThreshold = 0.4
        if SlideBoostCooldown > 0.0 then
            SlideBoostCooldown = SlideBoostCooldown - DeltaTick
        else
            if crouch < CrouchResetThreshold then
                SlideBoostReady = 0
            end
        end
    else
        SlideBoostCooldown = SlideBoostCooldownMax
        -- MinimumCrouch = MinimumCrouchDefault
        -- CrouchResetThreshold = CrouchResetThresholdDefault
    end
    if crouch > MinimumCrouch and crouch < FullCrouch and grounded == true then
        CanSlideBoost = true
    else
        CanSlideBoost = false
    end
    if crouch > MinimumCrouch and grounded == true then
        CanSlide = true
    else
        CanSlide = false
    end
    if VecLength(PlayerVelocity) <= 0.75 then
        IsSliding = false
    elseif grounded == true and CanSlide == false then
        IsSliding = false
    end

    if SlideBoostReady == 1 then
        if CanSlideBoost == true then
            SlideVelocity = PlayerVelocity
            SlideBoostCall = true
            PostEvent("SlideBoostCall",SlideBoostCall)
            IsSliding = true
            SlideBoostReady = 2
        end
    elseif SlideBoostReady ~= 0 then
        if CanSlide == true then
            if IsSliding == true then
                SlideCall = true
                PostEvent("SlideCall",SlideCall)
            else
                SlideVelocity = PlayerVelocity
                IsSliding = true
            end
        end
    end
    if grounded == false then
        if IsSliding == true then
            SlideCallFrequency = SlideCallFrequency - DeltaTick
            if SlideCallFrequency <= 0 then
                PreserveAirMomentumCall = true
                PostEvent("PreserveAirMomentumCall",PreserveAirMomentumCall)
                SlideCallFrequency = SlideCallFrequencyMax
            end
        end
    end

    if crouch > MinimumCrouch then
        -- DebugWatch("Crouch",crouch,false)
    end
    if VecLength(ForceDir) > 0 then
        -- DebugWatch("ForceDir from JumpKit()",ForceDir,false)
    end
    -- DebugWatch("SlideBoostReady",SlideBoostReady,false)
    -- DebugWatch("SlideBoostCooldown",SlideBoostCooldown,false)
    -- DebugWatch("IsSliding",IsSliding,false)
    -- DebugWatch("Velocity",playerVelocity,false)
    -- DebugWatch("SlideVelocity",SlideVelocity,false)
end
function server.playerSlideBoost()
    SlideBoostCall = false
    SlideBoostInputMultiplier = GetEvent("SlideBoostInputMultiplier",1)
    local newVelocity = Vec(PlayerVelocity[1] + ((PlayerVelocity[1]*SlideBoostMultiplier)*SlideBoostInputMultiplier), 0, PlayerVelocity[3] + ((PlayerVelocity[3]*SlideBoostMultiplier)*SlideBoostInputMultiplier))
    SlideVelocity = newVelocity
    SetPlayerVelocity(newVelocity, ServerLocalPlayer)
    -- DebugWatch("server.playerSlideBoost Velocity",newVelocity,false)
    -- DebugWatch("","Applying Jumpkit forward momentum...",false)
end
function server.playerSlide()
    SlideCall = false
    local velocityLength = VecLength(PlayerVelocity)
    local slideVelocityLength = VecLength(SlideVelocity)
    SlideVelocity = VecScale(SlideVelocity, SlideVelocityDecayMultiplier)
    if velocityLength < slideVelocityLength then
        SlideVelocity = PlayerVelocity
    end
    local newVelocity = Vec(SlideVelocity[1], 0, SlideVelocity[3])
    SetPlayerGroundVelocity(newVelocity, ServerLocalPlayer)
    -- DebugWatch("server.PlayerSlide Velocity",newVelocity,false)
end
function server.playerPreserveAirMomentum()
    PreserveAirMomentumCall = false
    local newVelocity = Vec(PlayerVelocity[1]*AirMomentumMultiplier, PlayerVelocity[2], PlayerVelocity[3]*AirMomentumMultiplier)
    SetPlayerVelocity(newVelocity, ServerLocalPlayer)
    -- DebugWatch("","Applying Jumpkit forward momentum to air...",false)
end

PreventFallDamageCall = false
FallCheckDir = Vec(0,-1,0)
FallCheckDistanceMultiplier = 0.4
FallCheckCastRadius = 1
FallCheckCast = {hit=false,dist=0,normal=Vec(),shape=0}
FallMaxVelocity = -10
FallVelocityMultiplier = 0.99
FallCheckCallFrequencyMax = 0.001
FallCheckCallFrequency = FallCheckCallFrequencyMax
function FallCheck()
    local playerTransform = GetPlayerTransform(0)
    if PlayerVelocity[2] < FallMaxVelocity then
        FallCheckCast.hit,FallCheckCast.dist,FallCheckCast.normal,FallCheckCast.shape = QueryRaycast(playerTransform.pos, FallCheckDir, -PlayerVelocity[2]*FallCheckDistanceMultiplier, FallCheckCastRadius, false)
        if FallCheckCast.hit == true then
            FallCheckCallFrequency = FallCheckCallFrequency - DeltaTick
            if FallCheckCallFrequency <= 0 then
                PreventFallDamageCall = true
                PostEvent("PreventFallDamageCall",PreventFallDamageCall)
                FallCheckCallFrequency = FallCheckCallFrequencyMax
            end
        end
        -- DebugLine(playerTransform.pos, VecAdd(playerTransform.pos, VecScale(FallCheckDir, FallCheckCast.dist)), Pink.r, Pink.g, Pink.b, 1)
        -- DebugWatch("Y Velocity",playerVelocity[2],false)
        -- DebugWatch("FallCheckCast",FallCheckCast,false)
    end
end
function server.playerPreventFallDamage()
    PreventFallDamageCall = false
    SetPlayerVelocity(Vec(PlayerVelocity[1], PlayerVelocity[2]*FallVelocityMultiplier, PlayerVelocity[3]), ServerLocalPlayer)
    -- DebugWatch("","Applying Jumpkit hover...",false)
end