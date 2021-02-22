# TODO(bernhard): think about where to put function definition of MSBSETVARS(), MSBDAYNIGHT()
"""MSBSETVARS() function that computes state dependent parameters for
updating states INTS, INTR, SNOW, CC, SNOWLQ in callback function
"""
function MSBSETVARS(IDAY, #TODO(bernhard) just for debug... remove again!
                    # arguments
                    IMODEL,
                    # for SUNDS
                    p_LAT, p_ESLOPE, DOY, p_L1, p_L2,
                    # for CANOPY
                    p_fT_HEIGHT, p_fT_LAI, p_fT_SAI, u_SNOW, p_SNODEN, p_MXRTLN, p_MXKPL, p_fT_DENSEF,
                    #
                    p_Z0S, p_Z0G,
                    # for ROUGH
                    p_ZMINH, p_CZS, p_CZR, p_HS, p_HR, p_LPC, p_CS,
                    # for PLNTRES
                    NLAYER, p_THICK, p_STONEF, p_fT_RELDEN, p_RTRAD, p_FXYLEM,
                    # for WEATHER
                    p_fT_TMAX, p_fT_TMIN, p_fT_EA, p_fT_UW, p_WNDRAT, p_FETCH, p_Z0W, p_ZW, p_fT_SOLRAD,
                    # for SNOFRAC
                    p_RSTEMP,
                    #
                    u_CC, p_CVICE,
                    # for SNOVAP
                    p_LWIDTH, p_RHOTP, p_NN, p_KSNVP,
                    #
                    p_ALBSN, p_ALB,
                    # for FRSS
                    p_RSSA, p_RSSB, p_PSIF, u_aux_PSIM, p_PsiCrit, #p_PSIF[1], u_aux_PSIM[1]
                    # for SNOENRGY
                    p_CCFAC, p_MELFAC, p_LAIMLT, p_SAIMLT)
    #
    # solar parameters depending on only on DOY
    # TODO(bernhard): a) Do this outside of integration loop in define_DiffEq_parameters() p_fT_DAYLEN
    p_fT_DAYLEN, p_fT_I0HDAY, p_fT_SLFDAY = LWFBrook90Julia.SUN.SUNDS(p_LAT, p_ESLOPE, DOY, p_L1, p_L2, LWFBrook90Julia.CONSTANTS.p_SC, LWFBrook90Julia.CONSTANTS.p_PI, LWFBrook90Julia.CONSTANTS.p_WTOMJ)

    # canopy parameters depending on DOY as well as different state depending parameters
    p_fu_HEIGHTeff, p_fu_LAIeff, p_fT_SAIeff, p_fu_RTLEN, p_fu_RPLANT =
        LWFBrook90Julia.PET.LWFBrook90_CANOPY(p_fT_HEIGHT,
                          p_fT_LAI,  # leaf area index, m2/m2, minimum of 0.00001
                          p_fT_SAI,  # stem area index, m2/m2
                          u_SNOW,    # water equivalent of snow on the ground, mm
                          p_SNODEN,  # snow density, mm/mm
                          p_MXRTLN,  # maximum root length per unit land area, m/m2
                          p_MXKPL,   # maximum plant conductivity, (mm/d)/MPa
                          p_fT_DENSEF)

    # roughness parameters depending on u_SNOW
    if (u_SNOW > 0)
        p_fu_Z0GS = p_Z0S
    else
        p_fu_Z0GS = p_Z0G
    end
    p_fu_Z0GS, p_fu_Z0C, p_fu_DISPC, p_fu_Z0, p_fu_DISP, p_fu_ZA =
            LWFBrook90Julia.PET.ROUGH(p_fu_HEIGHTeff, p_ZMINH, p_fu_LAIeff, p_fT_SAIeff,
                                      p_CZS, p_CZR, p_HS, p_HR, p_LPC, p_CS, p_fu_Z0GS)

    # plant resistance components
    p_fu_RXYLEM, p_fu_RROOTI, p_fu_ALPHA = LWFBrook90Julia.EVP.PLNTRES(NLAYER, p_THICK, p_STONEF, p_fu_RTLEN, p_fT_RELDEN, p_RTRAD, p_fu_RPLANT, p_FXYLEM, LWFBrook90Julia.CONSTANTS.p_PI, LWFBrook90Julia.CONSTANTS.p_RHOWG)

    # calculated weather data
    p_fu_SHEAT = 0
    (p_fu_SOLRADC, p_fu_TA, p_fu_TADTM, p_fu_TANTM, UA, p_fu_UADTM, p_fu_UANTM) =
        LWFBrook90Julia.PET.WEATHER(p_fT_TMAX, p_fT_TMIN, p_fT_DAYLEN, p_fT_I0HDAY, p_fT_EA, p_fT_UW, p_fu_ZA, p_fu_DISP, p_fu_Z0, p_WNDRAT, p_FETCH, p_Z0W, p_ZW, p_fT_SOLRAD)
    # fraction of precipitation as p_fT_SFAL
    p_fT_SNOFRC= LWFBrook90Julia.SNO.SNOFRAC(p_fT_TMAX, p_fT_TMIN, p_RSTEMP)

    if (u_SNOW > 0)
        # snowpack temperature at beginning of day
        p_fu_TSNOW = -u_CC / (p_CVICE * u_SNOW)
        # potential snow evaporation PSNVP
        p_fu_PSNVP=LWFBrook90Julia.SNO.SNOVAP(p_fu_TSNOW, p_fu_TA, p_fT_EA, UA, p_fu_ZA, p_fu_HEIGHTeff, p_fu_Z0, p_fu_DISP, p_fu_Z0C, p_fu_DISPC, p_fu_Z0GS, p_LWIDTH, p_RHOTP, p_NN, p_fu_LAIeff, p_fT_SAIeff, p_KSNVP)
        p_fu_ALBEDO = p_ALBSN
        p_fu_RSS = 0
    else
        p_fu_TSNOW = 0
        p_fu_PSNVP = 0
        p_fu_ALBEDO = p_ALB
        # soil evaporation resistance
        p_fu_RSS = LWFBrook90Julia.PET.FRSS(p_RSSA, p_RSSB, p_PSIF[1], u_aux_PSIM[1], p_PsiCrit[1])

        # check for zero or negative p_fu_RSS (TODO: not done in LWFBrook90)
        #if (p_fu_RSS < 0.000001)
        #    error("p_fu_RSS is very small or negative. Run ends. Check p_RSSA and p_RSSB values.")
        #end
    end

    # snow surface energy balance (is performed even when SNOW=0 in case snow is added during day)
    p_fu_SNOEN = LWFBrook90Julia.SNO.SNOENRGY(p_fu_TSNOW, p_fu_TA, p_fT_DAYLEN, p_CCFAC, p_MELFAC, p_fT_SLFDAY, p_fu_LAIeff, p_fT_SAIeff, p_LAIMLT, p_SAIMLT)

    return (p_fT_DAYLEN, p_fT_I0HDAY, p_fT_SLFDAY,
            p_fu_HEIGHTeff, p_fu_LAIeff, p_fT_SAIeff, p_fu_RTLEN, p_fu_RPLANT,
            p_fu_Z0GS, p_fu_Z0C, p_fu_DISPC, p_fu_Z0, p_fu_DISP, p_fu_ZA,
            p_fu_RXYLEM, p_fu_RROOTI, p_fu_ALPHA,
            p_fu_SHEAT,
            p_fu_SOLRADC, p_fu_TA, p_fu_TADTM, p_fu_TANTM, p_fu_UADTM, p_fu_UANTM,
            p_fT_SNOFRC,
            p_fu_TSNOW,p_fu_PSNVP, p_fu_ALBEDO,p_fu_RSS,
            p_fu_SNOEN)
end


function MSBDAYNIGHT(IDAY, #TODO(bernhard) just for debug... remove again!
                     IMODEL,
                     # arguments
                     p_fT_SLFDAY, p_fu_SOLRADC, p_WTOMJ, p_fT_DAYLEN, p_fu_TADTM, p_fu_UADTM, p_fu_TANTM, p_fu_UANTM,
                     p_fT_I0HDAY,
                     # for AVAILEN:
                     p_fu_ALBEDO, p_C1, p_C2, p_C3, p_fT_EA, p_fu_SHEAT, p_CR, p_fu_LAIeff, p_fT_SAIeff,
                     # for SWGRA:
                     p_fu_ZA, p_fu_HEIGHTeff, p_fu_Z0, p_fu_DISP, p_fu_Z0C, p_fu_DISPC, p_fu_Z0GS, p_LWIDTH, p_RHOTP, p_NN,
                     # for SRSC:
                     p_fu_TA, p_GLMIN, p_GLMAX, p_R5, p_CVPD, p_RM, p_TL, p_T1, p_T2, p_TH,
                     # for SWPE:
                     p_fu_RSS,
                     # for TBYLAYER:
                     p_fu_ALPHA, p_fu_KK, p_fu_RROOTI, p_fu_RXYLEM, u_aux_PSITI, NLAYER, p_PSICR, NOOUTF)
    # MSBDAYNIGHT() computes the five components of evaporation:
    # - aux_du_ISVP: evaporation of intercepted snow
    # - aux_du_IRVP: evaporation of intercepted rain
    # - aux_du_SNVP: evaporation from snow
    # - aux_du_SLVP: soil evaporation from the top soil layer
    # - aux_du_TRANI: transpiration from each soil layer that contains roots

    p_fu_PTR = fill(NaN, 2)
    p_fu_GER = fill(NaN, 2)
    p_fu_PIR = fill(NaN, 2)
    p_fu_GIR = fill(NaN, 2)
    p_fu_ATRI=fill(NaN,2,NLAYER)

    if IMODEL == 1
        p_fu_PGER = fill(NaN, 2) # fill in values further down
    else
        p_fu_PGER = fill(NaN, 2) # don't fill in values, simply return NaN
    end

    ATR = fill(NaN, 2)
    SLRAD=fill(NaN,2)
    for J = 1:2 # 1 for daytime, 2 for nighttime

        # net radiation
        if (J ==1)
            SLRAD[J] = p_fT_SLFDAY * p_fu_SOLRADC / (p_WTOMJ * p_fT_DAYLEN)
            TAJ = p_fu_TADTM
            UAJ = p_fu_UADTM
        else
            SLRAD[J] = 0
            TAJ = p_fu_TANTM
            UAJ = p_fu_UANTM
        end

        # if (p_fT_I0HDAY <= 0.01)
        #     # TODO(bernhard): Brook90 did treat this case specially, LWFBrook90 did not
        #
        #     # no sunrise, assume 50% clouds for longwave
        #     cloud_fraction = 0.5
        # else
        cloud_fraction = p_fu_SOLRADC / p_fT_I0HDAY
        # end
        AA, ASUBS =
            LWFBrook90Julia.SUN.AVAILEN(SLRAD[J], p_fu_ALBEDO, p_C1, p_C2, p_C3, TAJ, p_fT_EA,
                    cloud_fraction,
                    p_fu_SHEAT, p_CR, p_fu_LAIeff, p_fT_SAIeff)

        # vapor pressure deficit
        ES, DELTA = LWFBrook90Julia.PET.ESAT(TAJ)
        VPD = ES - p_fT_EA
        # S.-W. resistances
        RAA, RAC, RAS = LWFBrook90Julia.PET.SWGRA(UAJ, p_fu_ZA, p_fu_HEIGHTeff, p_fu_Z0, p_fu_DISP, p_fu_Z0C, p_fu_DISPC, p_fu_Z0GS, p_LWIDTH, p_RHOTP, p_NN, p_fu_LAIeff, p_fT_SAIeff)
        if (J == 1)
            RSC=LWFBrook90Julia.PET.SRSC(SLRAD[J], p_fu_TA, VPD, p_fu_LAIeff, p_fT_SAIeff, p_GLMIN, p_GLMAX, p_R5, p_CVPD, p_RM, p_CR, p_TL, p_T1, p_T2, p_TH)
        else
            RSC = 1 / (p_GLMIN * p_fu_LAIeff)
        end

        #print("\nIDAY:$(@sprintf("% 3d", IDAY)), J = $J     AA:$(@sprintf("% 8.4f", AA)), ASUBS:$(@sprintf("% 8.4f", ASUBS)), VPD:$(@sprintf("% 8.4f", VPD)), RAA:$(@sprintf("% 8.4f", RAA)), RAC:$(@sprintf("% 8.4f", RAC)), RAS:$(@sprintf("% 8.4f", RAS)), RSC:$(@sprintf("% 8.4f", RSC)), p_fu_RSS:$(@sprintf("% 8.4f", p_fu_RSS)), DELTA:$(@sprintf("% 8.4f", DELTA))")

        # S.-W. potential transpiration and ground evaporation rates
        p_fu_PTR[J], p_fu_GER[J] =  LWFBrook90Julia.PET.SWPE(AA, ASUBS, VPD, RAA, RAC, RAS, RSC, p_fu_RSS, DELTA)
        # S.-W. potential interception and ground evap. rates
        # RSC = 0, p_fu_RSS not changed
        p_fu_PIR[J], p_fu_GIR[J] =  LWFBrook90Julia.PET.SWPE(AA, ASUBS, VPD, RAA, RAC, RAS, 0, p_fu_RSS, DELTA)

        if IMODEL == 1
            # S.-W. potential interception and ground evap. rates
            # RSC not changed, p_fu_RSS = 0
            _, p_fu_PGER[J] =  LWFBrook90Julia.PET.SWPE(AA, ASUBS, VPD, RAA, RAC, RAS, RSC, 0, DELTA)
        end
        # actual transpiration and ground evaporation rates
        if (p_fu_PTR[J] > 0.001)
            ATR[J], ATRANI = LWFBrook90Julia.EVP.TBYLAYER(J, p_fu_PTR[J], p_fu_DISPC, p_fu_ALPHA, p_fu_KK, p_fu_RROOTI, p_fu_RXYLEM, u_aux_PSITI, NLAYER, p_PSICR, NOOUTF)
            for i = 1:NLAYER
                p_fu_ATRI[J,i] = ATRANI[i]
            end
            if (ATR[J] < p_fu_PTR[J])
                # soil water limitation, new GER
                p_fu_GER[J]=LWFBrook90Julia.PET.SWGE(AA, ASUBS, VPD, RAA, RAS, p_fu_RSS, DELTA, ATR[J])
            end
        else
            # no transpiration, condensation ignored
            p_fu_PTR[J] = 0
            ATR[J] = 0
            for i = 1:NLAYER
                p_fu_ATRI[J,i] = 0
            end
            p_fu_GER[J]=LWFBrook90Julia.PET.SWGE(AA, ASUBS, VPD, RAA, RAS, p_fu_RSS, DELTA, 0)
        end
    end
    #print("\nIDAY:$(@sprintf("% 3d", IDAY)), p_fu_GER[1]: $(@sprintf("% 8.4f",p_fu_GER[1])), p_fu_GIR[1]: $(@sprintf("% 8.4f",p_fu_GIR[1]))")
    # print(", p_fu_GER[2]: $(@sprintf("% 8.4f",p_fu_GER[2])), p_fu_GIR[2]: $(@sprintf("% 8.4f",p_fu_GIR[2]))")

    # print(", AA:$(@sprintf("% 8.4f", AA)), ASUBS:$(@sprintf("% 8.4f", ASUBS)), VPD:$(@sprintf("% 8.4f", VPD)), RAA:$(@sprintf("% 8.4f", RAA)), RAC:$(@sprintf("% 8.4f", RAC)), RAS:$(@sprintf("% 8.4f", RAS)), p_fu_RSS:$(@sprintf("% 8.4f", p_fu_RSS)), DELTA:$(@sprintf("% 8.4f", DELTA))")
    # print(", J:$(@sprintf("% 8.4f", J)), p_fu_PIR[J]:$(@sprintf("% 8.4f", p_fu_PIR[J])))")
    # print("\n        ")
    return (p_fu_PTR, # potential transpiration rate for daytime or night (mm/d)
            p_fu_GER, # ground evaporation rate for daytime or night (mm/d)
            p_fu_PIR, # potential interception rate for daytime or night (mm/d)
            p_fu_GIR, # ground evap. rate with intercep. for daytime or night (mm/d)
            p_fu_ATRI,# actual transp.rate from layer for daytime and night (mm/d)
            p_fu_PGER)

    # return (#SLRAD[2],SLRAD[1],TAJ,UAJ, SOVERI, AA, ASUBS
    #         #ES, DELTA, VPD, RAA, RAC, RAS, RSC,
    #         p_fu_PTR, p_fu_GER, p_fu_PIR, p_fu_GIR,
    #         #ATR, ATRANI,
    #         p_fu_ATRI)
end


function MSBDAYNIGHT_postprocess(IMODEL, NLAYER,
                                 p_fu_PTR, # potential transpiration rate for daytime or night (mm/d)
                                 p_fu_GER, # ground evaporation rate for daytime or night (mm/d)
                                 p_fu_PIR, # potential interception rate for daytime or night (mm/d)
                                 p_fu_GIR, # ground evap. rate with intercep. for daytime or night (mm/d)
                                 p_fu_ATRI,# actual transp.rate from layer for daytime and night (mm/d)
                                 p_fT_DAYLEN,
                                 p_fu_PGER,
                                 p_DT)

    # average rates over day
    p_fu_PTRAN = (p_fu_PTR[1] * p_fT_DAYLEN + p_fu_PTR[2] * (1 - p_fT_DAYLEN)) / p_DT #TODO(bernhard) why "/ p_DT"? This seems wrong.
    p_fu_GEVP  = (p_fu_GER[1] * p_fT_DAYLEN + p_fu_GER[2] * (1 - p_fT_DAYLEN)) / p_DT #TODO(bernhard) why "/ p_DT"? This seems wrong.
    p_fu_PINT  = (p_fu_PIR[1] * p_fT_DAYLEN + p_fu_PIR[2] * (1 - p_fT_DAYLEN)) / p_DT #TODO(bernhard) why "/ p_DT"? This seems wrong.
    p_fu_GIVP  = (p_fu_GIR[1] * p_fT_DAYLEN + p_fu_GIR[2] * (1 - p_fT_DAYLEN)) / p_DT #TODO(bernhard) why "/ p_DT"? This seems wrong.

    if IMODEL==1
        p_fu_PSLVP = (p_fu_PGER[1] * p_fT_DAYLEN + p_fu_PGER[2] * (1 - p_fT_DAYLEN)) / p_DT #TODO(bernhard) why "/ p_DT"? This seems wrong.
    end

    aux_du_TRANI=zeros(NLAYER)

    for i = 1:NLAYER
        aux_du_TRANI[i] = (p_fu_ATRI[1, i] * p_fT_DAYLEN + p_fu_ATRI[2, i] * (1 - p_fT_DAYLEN)) / p_DT #TODO(bernhard) why "/ p_DT"? This seems wrong.
    end

    return (p_fu_PTRAN, # average potential transpiration rate for day (mm/d)
            p_fu_GEVP,  # average ground evaporation for day (mm/d)
            p_fu_PINT,  # average potential interception for day (mm/d)
            p_fu_GIVP,  # average ground evaporation for day with interception (mm/d)
            p_fu_PSLVP, # average potential evaporation rate from soil for day (mm/d) TODO(bernhard) seems unused further on
            aux_du_TRANI) # average transpiration rate for day from layer (mm/d)
end


function MSBPREINT(#arguments:
                   #
                   p_fT_PREINT, p_DTP, p_fT_SNOFRC, p_NPINT, p_fu_PINT, p_fu_TA,
                   # for INTER (snow)
                   u_INTS, p_fu_LAI, p_fu_SAI, p_FSINTL, p_FSINTS, p_CINTSL, p_CINTSS,
                   # for INTER (rain)
                   u_INTR, p_FRINTL, p_FRINTS, p_CINTRL, p_CINTRS,
                   # for INTER24 (snow + rain)
                   p_DURATN, MONTHN,
                   #
                   u_SNOW, p_fu_PTRAN, NLAYER, aux_du_TRANI, p_fu_GIVP, p_fu_GEVP,
                   # for SNOWPACK
                   u_CC, u_SNOWLQ, p_fu_PSNVP, p_fu_SNOEN, p_MAXLQF, p_GRDMLT)

    p_fT_PREC = p_fT_PREINT / p_DTP     # PREINT in mm, PREC as rate in mm/day # TODO: check is PREINT in mm?
    p_fT_SFAL = p_fT_SNOFRC * p_fT_PREC # rate in mm/day
    p_fT_RFAL = p_fT_PREC - p_fT_SFAL   # rate in mm/day

    if (p_NPINT > 1.0)
        # more than one precip interval in day
        # snow interception
        if (p_fu_PINT < 0 && p_fu_TA > 0)
            # prevent frost when too warm, carry negative p_fu_PINT to rain
            aux_du_SINT, aux_du_ISVP = LWFBrook90Julia.EVP.INTER(p_fT_SFAL, 0, p_fu_LAI, p_fu_SAI, p_FSINTL, p_FSINTS, p_CINTSL, p_CINTSS, p_DTP, u_INTS)
        else
            aux_du_SINT, aux_du_ISVP = LWFBrook90Julia.EVP.INTER(p_fT_SFAL, p_fu_PINT, p_fu_LAI, p_fu_SAI, p_FSINTL, p_FSINTS, p_CINTSL, p_CINTSS, p_DTP, u_INTS)
        end
        # rain interception,  note potential interception rate is PID/p_DT-aux_du_ISVP
        aux_du_RINT, aux_du_IRVP = LWFBrook90Julia.EVP.INTER(p_fT_RFAL, p_fu_PINT - aux_du_ISVP, p_fu_LAI, p_fu_SAI, p_FRINTL, p_FRINTS, p_CINTRL, p_CINTRS, p_DTP, u_INTR)
    else
        # one precip interval in day, use storm p_DURATN and INTER24
        # snow interception
        if (p_fu_PINT < 0 && p_fu_TA > 0)
            # prevent frost when too warm, carry negative p_fu_PINT to rain
            aux_du_SINT, aux_du_ISVP = LWFBrook90Julia.EVP.INTER24(p_fT_SFAL, 0, p_fu_LAI, p_fu_SAI, p_FSINTL, p_FSINTS, p_CINTSL, p_CINTSS, p_DURATN, u_INTS, MONTHN)
        else
            aux_du_SINT, aux_du_ISVP = LWFBrook90Julia.EVP.INTER24(p_fT_SFAL, p_fu_PINT, p_fu_LAI, p_fu_SAI, p_FSINTL, p_FSINTS, p_CINTSL, p_CINTSS, p_DURATN, u_INTS, MONTHN)
        end
        # rain interception,  note potential interception rate is PID/p_DT-aux_du_ISVP
        aux_du_RINT, aux_du_IRVP = LWFBrook90Julia.EVP.INTER24(p_fT_RFAL, p_fu_PINT - aux_du_ISVP, p_fu_LAI, p_fu_SAI, p_FRINTL, p_FRINTS, p_CINTRL, p_CINTRS, p_DURATN, u_INTR, MONTHN)
    end

    # throughfall
    p_fu_RTHR = p_fT_RFAL - aux_du_RINT
    p_fu_STHR = p_fT_SFAL - aux_du_SINT

    # reduce transpiration for fraction of precip interval that canopy is wet
    p_fu_WETFR = min(1.0, (aux_du_IRVP + aux_du_ISVP) / p_fu_PINT)
    p_fu_PTRAN = (1.0 - p_fu_WETFR) * p_fu_PTRAN
    for i = 1:NLAYER
        aux_du_TRANI[i] = (1.0 - p_fu_WETFR) * aux_du_TRANI[i]
    end
    if (u_SNOW <= 0 && p_fu_STHR <= 0)
        # no snow, soil evaporation weighted for p_fu_WETFR
        aux_du_SLVP = p_fu_WETFR * p_fu_GIVP + (1.0 - p_fu_WETFR) * p_fu_GEVP
        p_fu_RNET = p_fu_RTHR
        aux_du_RSNO = 0.0
        aux_du_SNVP = 0.0
        aux_du_SMLT = 0.0
    else
        if (u_SNOW <= 0 && p_fu_STHR > 0)
            # new snow only, zero CC and SNOWLQ assumed
            u_CC = 0.0
            u_SNOWLQ = 0.0
        end
        # snow accumulation and melt
        u_CC, u_SNOW, u_SNOWLQ, aux_du_RSNO, aux_du_SNVP, aux_du_SMLT =
          LWFBrook90Julia.SNO.SNOWPACK(p_fu_RTHR, p_fu_STHR, p_fu_PSNVP, p_fu_SNOEN,
                   # States that are overwritten:
                   u_CC, u_SNOW, u_SNOWLQ,
                   p_DTP, p_fu_TA, p_MAXLQF, p_GRDMLT)

        p_fu_RNET = p_fu_RTHR - aux_du_RSNO
        aux_du_SLVP = 0.0
    end

    return (# compute some fluxes as intermediate results:
            p_fT_SFAL, p_fT_RFAL, p_fu_RNET, p_fu_PTRAN,
            # compute changes in soil water storage:
            aux_du_TRANI, aux_du_SLVP,
            # compute change in interception storage:
            aux_du_SINT, aux_du_ISVP, aux_du_RINT, aux_du_IRVP,
            # compute change in snow storage:
            aux_du_RSNO, aux_du_SNVP, aux_du_SMLT,
            # compute updated states:
            u_SNOW, u_CC, u_SNOWLQ)
end


function MSBITERATE(IMODEL, p_QLAYER,
                    # for SRFLFR:
                    u_SWATI, p_SWATQX, p_QFPAR, p_SWATQF, p_QFFC,
                    #
                    p_IMPERV, p_fu_RNET, aux_du_SMLT, NLAYER,
                    p_LENGTH, p_DSLOPE,
                    # for DSLOP:
                    p_RHOWG, u_aux_PSIM, p_THICK, p_STONEF, p_fu_KK,
                    #
                    u_aux_PSITI, p_DPSIMX,
                    # for VERT:
                    p_KSAT,
                    #
                    p_DRAIN, p_DTP, p_DTIMAX,
                    # for INFLOW:
                    p_INFRAC, p_fu_BYFRAC, aux_du_TRANI, aux_du_SLVP, p_SWATMX,
                    # for ITER:
                    u_aux_θ, u_aux_WETNES,
                    p_DSWMAX, p_THSAT, p_θr, p_BEXP, p_PSIF, p_WETF, p_CHM, p_CHN, p_WETINF, p_MvGα, p_MvGn,
                    # for GWATER:
                    u_GWAT, p_GSC, p_GSP, p_DT)

    ## On soil surface, partition incoming rain (RNET) and melt water (SMLT)
    # into either above ground source area flow (streamflow, SRFL) or
    # below ground ("infiltrated") input to soil (SLFL)
    # source area flow rate
    if (p_QLAYER > 0)
        SAFRAC=LWFBrook90Julia.WAT.SRFLFR(p_QLAYER, u_SWATI, p_SWATQX, p_QFPAR, p_SWATQF, p_QFFC)
    else
        SAFRAC = 0.
    end
    p_fu_SRFL = min(1., (p_IMPERV + SAFRAC)) * (p_fu_RNET + aux_du_SMLT)

    # water supply rate to soil surface:
    p_fu_SLFL = p_fu_RNET + aux_du_SMLT - p_fu_SRFL

    ## Within soil compute flows from layers:
    #  a) vertical flux between layers VRFLI,
    #  b) downslope flow from the layers DSFLI
    aux_du_VRFLI = fill(NaN, NLAYER)
    aux_du_DSFLI = fill(NaN, NLAYER)

    # downslope flow rates
    for i = NLAYER:-1:1
        aux_du_DSFLI[i] = LWFBrook90Julia.WAT.DSLOP(u_aux_PSIM[i], p_fu_KK[i], p_DSLOPE, p_LENGTH, p_THICK[i], p_STONEF[i], p_RHOWG, )
    end

    ### vertical flow rates

    # vertical flow rates
    # 1) first approximation on aux_du_VRFLI
    for i = NLAYER:-1:1
        aux_du_VRFLI[i] = LWFBrook90Julia.WAT.VRFLI(i, NLAYER, u_aux_PSITI, p_fu_KK, p_KSAT, p_THICK, p_STONEF, p_RHOWG, p_DRAIN, p_DPSIMX)
    end

    # NOTE(bernhard): originally Brook90 and LWFBrook90R used the first approximation from
    #                 VRFLI() for both calls to INFLOW()
    #                 i.e. calling INFLOW(..., aux_du_VRFLI_1st_approx) weith DTI and DTINEW
    aux_du_VRFLI_1st_approx = aux_du_VRFLI

    # first approximation for iteration time step,time remaining or DTIMAX
    DTRI = p_DTP
    DTI  = min(DTRI, p_DTIMAX)

    # vertical flow rates
    # second approximation on aux_du_VRFLI
    # correct aux_du_VRFLI and compute aux_du_INFLI, aux_du_BYFLI, du_NTFLI

    # net inflow to each layer including E and T withdrawal adjusted for interception
    aux_du_VRFLI, aux_du_INFLI, aux_du_BYFLI, du_NTFLI =
        LWFBrook90Julia.WAT.INFLOW(NLAYER, DTI, p_INFRAC, p_fu_BYFRAC, p_fu_SLFL, aux_du_DSFLI, aux_du_TRANI,
                                    aux_du_SLVP, p_SWATMX, u_SWATI,
                                    aux_du_VRFLI_1st_approx)

    # limit step size
    #   ITER computes DTI so that the potential difference (due to aux_du_VRFLI)
    #   between adjacent layers does not change sign during the iteration time step
    if (true)
        # NOTE: when using DiffEq.jl the integrator time step is determined by solve().
        # On might think, that therefore the adaptive time step control of LWFBrook can be deactivated.
        # However, this is not the case. DTI is used in INFLOW() to compute the fluxes aux_du_VRFLI, ... etc.
        DTINEW=LWFBrook90Julia.WAT.ITER(IMODEL, NLAYER, DTI, LWFBrook90Julia.CONSTANTS.p_DTIMIN,
                                        du_NTFLI, u_aux_PSITI, u_aux_θ,
                                        u_aux_WETNES,
                                        LWFBrook90Julia.KPT.FDPSIDWF_CH, LWFBrook90Julia.KPT.FDPSIDWF_MvG,
                                        p_WETINF, p_BEXP, p_PSIF, p_WETF, p_CHM, p_CHN,
                                        p_MvGα, p_MvGn,
                                        p_DSWMAX, p_DPSIMX, p_THICK, p_STONEF, p_THSAT, p_θr)
                                        # TODO(bernhard): we compute DTINEW and it is used for computation of fluxes: aux_dU_VRFLI, ...
                                        #                 but it is not passed to DiffEq.jl.solve() to modify the step
                                        #                 Alternatively:
                                        #                 1) we could use a DiffEq.jl callback if the solution leaves a specified domain:
                                        #                 https://diffeq.sciml.ai/stable/features/callback_library/#PositiveDomain
                                        #                 https://diffeq.sciml.ai/stable/features/callback_library/#GeneralDomain
                                        #                 2) we could use a DiffEq.jl callback to compute DTINEW and set it in DiffEq.jl using
                                        #                 https://diffeq.sciml.ai/stable/basics/integrator/#DiffEqBase.set_proposed_dt!
                                        #                 However, this only affects the next time step and not the ongoing one as it does in LWFBrook90

        # recompute step
        if (DTINEW < DTI)
            # recalculate flow rates with new DTI

            # vertical flow rates
            # third approximation on aux_du_VRFLI
            # correct aux_du_VRFLI and compute aux_du_INFLI, aux_du_BYFLI, du_NTFLI
            DTI = DTINEW
            aux_du_VRFLI, aux_du_INFLI, aux_du_BYFLI, du_NTFLI =
                LWFBrook90Julia.WAT.INFLOW(NLAYER, DTI, p_INFRAC, p_fu_BYFRAC, p_fu_SLFL, aux_du_DSFLI, aux_du_TRANI,
                                            aux_du_SLVP, p_SWATMX, u_SWATI,
                                            aux_du_VRFLI_1st_approx)
        end
    end

    ###

    # groundwater flow and seepage loss
    du_GWFL, du_SEEP = LWFBrook90Julia.WAT.GWATER(u_GWAT, p_GSC, p_GSP, p_DT, aux_du_VRFLI[NLAYER])

    return (p_fu_SRFL, p_fu_SLFL, aux_du_DSFLI, aux_du_VRFLI, aux_du_INFLI, aux_du_BYFLI, du_NTFLI, du_GWFL, du_SEEP, DTINEW)
end