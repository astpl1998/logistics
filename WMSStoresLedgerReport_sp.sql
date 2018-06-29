Text
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


/*$File_version=MS4.3.0.00$*/
/*
Modified By			Date			Purpose
Sujatha S			12/07/2012		CUBE_LIVE_WMS REPORT_00001
Sujatha S			16/07/2012		CUBE_LIVE_WMS REPORT_00003
Sujatha S			22/08/2012		CUBE_LIVE_WMS REPORT_00008
*/
create Procedure WMSStoresLedgerReport_sp
	@ctxt_ouinstance   	ctxt_ouinstance, --Input 
	@ctxt_user         	ctxt_user, --Input 
	@ctxt_language     	ctxt_language, --Input 
	@ctxt_service      	ctxt_service, --Input 
	@ctxt_role         	ctxt_role, --Input 
	@datefrom          	udd_date, --Input 
	@dateto            	udd_date, --Input 
	@hdnhiddencontrol1 	udd_hiddencontrol, --Input 
	@hdnhiddencontrol2 	udd_hiddencontrol, --Input 
	@hiddencontrol1    	udd_hiddencontrol, --Input 
	@hiddencontrol2    	udd_hiddencontrol, --Input 
	@inboundreport     	udd_counter, --Input 
	@itemcodefrom      	udd_hiddencontrol, --Input 
	@itemcodeto        	udd_hiddencontrol, --Input 
	@outboundreport    	udd_counter, --Input 
	@storesleadger     	udd_counter, --Input 
	@variantcode       	udd_hiddencontrol, --Input 
	@whcode            	udd_warehouse, --Input 
	@whdescription     	udd_warehousename, --Input 
	@inczeroqtystock	udd_counter,
	@m_errorid         	udd_int output
as	
begin

	set nocount on
	
	declare @ouname			udd_name
	declare @lo_id			udd_loid
	Declare @tran_date		udd_date
	Declare	@guid			udd_guid
	
	Select	@tran_date	=	dbo.RES_Getdate(@ctxt_ouinstance)
	Select	@guid		=	newid()
	
	Select	@ouname		= ouinstdesc
	From	emod_ou_mst_vw(nolock)
	where   map_status	  =	'M'
	and		ou_id		  = @ctxt_ouinstance
	
	select 	@lo_id = lo_id    
	from  	emod_lo_bu_ou_vw(nolock)
	where  	ou_id =  @ctxt_ouinstance
	and		@tran_date between effective_from and isnull(effective_to, @tran_date)
	
	if @datefrom is null
		select @datefrom = min(convert(nvarchar(10),trandate,120)) from wms_transaction_slbyval_vw (nolock) where ou = @ctxt_ouinstance
	else 
		select @datefrom = convert(nvarchar(10),@datefrom,120)
		
	if @dateto is null
		select @dateto = max(convert(nvarchar(10),trandate,120))from wms_transaction_slbyval_vw (nolock) where ou = @ctxt_ouinstance
	else 
		select @dateto = convert(nvarchar(10),@dateto,120)
		
		
		
	
	INSERT wms_inv_stlegr_tmp
	(guid,			ouname,			ouid,			warehouse,		whdesc,			itemcode,
	variant,		stockuom,		itemdesc,		transtype,		transno,
	transdate,		quantity,		refdocno,		reflineno,		refschno,
	tranmode,		udfield1,		trkcontno,		suppname,		lotno,
	slotno,			recqty,			recuom,			recstkqty,		stocksts,
	desqty,			desuom,			desstkqty,		zone_no,		bin_no)
	
	select
	@guid,			ouinstname,		ou,				warehouse,			wm_wh_desc,			itemcode,
	variantcode,	uom,			null,			null,				null,
	null,			sum(qty),		null,			null,				null,
	null,			null,			null,			null,				lotno,
	null,			sum(qty),		uom,			sum(stock_uom_qty),	null,
	0,				null,			0,				Zone,				bin
	from	wms_transaction_slbyval_vw (nolock)
	inner	join	fw_admin_view_ouinstance (nolock)
	on		(ouinstid		=	ou)
	inner Join	sa_wm_warehouse_master(nolock)
	On		warehouse			= wm_wh_code
	and ou					= wm_wh_ou
	where	warehouse		like	@whcode
	and		variantcode		like isnull(@variantcode,variantcode)
	and		itemcode between isnull(@itemcodefrom,itemcode) and isnull(@itemcodeto,itemcode) 
	and		convert(nvarchar(10),trandate,120)	between @datefrom and @dateto
	and		trantype		in ('Receipts','Opening Balance','Stock Transfer In','Returns','Adjustment')
	group by ouinstname,ou,		warehouse,		wm_wh_desc,			itemcode,
	variantcode,	uom,lotno,Zone,bin
	

	declare @gid	udd_guid,		@ou		udd_ctxt_ouinstance,	@wh		udd_warehouse,	@itm	udd_itemcode,
			@var	udd_variant,	@uomcd	udd_uomcode,			@trdt	udd_date,		@qty	udd_quantity,
			@ltno	udd_lotnumber,	@stksts udd_status,				@zn		udd_zone,		@bn		udd_bin,
			@desqty	udd_quantity,	@dstqty	udd_quantity,			@desuom	udd_uomcode,	@stkqty	udd_quantity
	
	declare desqtyupd cursor for
	select t.guid,	t.ouid,			t.warehouse,	t.itemcode,
	t.variant,		vw.uom,			t.transdate,	vw.qty,		
	t.lotno,		t.zone_no,		t.bin_no, vw.stock_uom_qty
	from	wms_inv_stlegr_tmp t(nolock),wms_transaction_slbyval_vw vw(nolock)
	where	guid					=	@guid
	and		vw.warehouse			=	t.warehouse
	and		vw.zone					=	t.zone_no
	and		vw.bin					=	t.bin_no
	and		vw.ou					=	t.ouid
	and		vw.itemcode				=	t.itemcode
	and		vw.variantcode			=	t.variant
	and		vw.lotno				=	t.lotno
	and		vw.warehouse		like	@whcode
	and		variantcode			like isnull(@variantcode,variantcode)
	and		vw.itemcode	between isnull(@itemcodefrom,vw.itemcode) and isnull(@itemcodeto,vw.itemcode) 
	and		convert(nvarchar(10),trandate,120)	between @datefrom	and @dateto
	and		trantype		in ('Issues','Stock Transfer Out')

	open desqtyupd
	
	fetch next from desqtyupd into @gid,@ou,@wh,@itm,@var,@uomcd,@trdt,@qty,@ltno,@zn,@bn,@stkqty
	
	while @@FETCH_STATUS = 0
	begin
		--select	@desqty = sum(qty),
		--		@dstqty	= sum(stock_uom_qty),
		--		@desuom	= uom
		--from	wms_transaction_slbyval_vw(nolock)
		--where	warehouse	=	@wh
		--and		Zone		=	@zn
		--and		Bin			=	@bn
		--and		variantcode	=	@var
		--and		itemcode	=	@itm
		--and		lotno		=	@ltno
		--and		ou			=	@ou
		--and		convert(nvarchar(10),trandate,120)	between @datefrom	and @dateto
		--and		trantype		in ('Issues','Stock Transfer Out')
		--group	by uom
		
			
		update t
		set		desqty		=	isnull(desqty,0) + @qty,
				desuom		=	@uomcd	,
				desstkqty	=	isnull(desstkqty,0) + @stkqty
		from	wms_inv_stlegr_tmp t (nolock)
		where	guid		=	@guid
		and		warehouse	=	@wh
		and		Zone_no		=	@zn
		and		Bin_no		=	@bn
		and		variant		=	@var
		and		itemcode	=	@itm
		and		lotno		=	@ltno
		and		ouid		=	@ou
		
		fetch next from desqtyupd into @gid,@ou,@wh,@itm,@var,@uomcd,@trdt,@qty,@ltno,@zn,@bn,@stkqty
	
	end

	close desqtyupd
	deallocate desqtyupd


	if exists (select '1' from wms_inv_stlegr_tmp (nolock) where guid = @guid)
	begin
		select @guid = @guid
	end
	else
	begin
		raiserror('No data available for the specified search criteria.',16,-1)
		return	
	end
	
	if @inczeroqtystock = 0
	begin
		update	wms_inv_stlegr_tmp
		set		balqty	=	recstkqty - desstkqty
		where	guid	=	@guid
		
		delete	from wms_inv_stlegr_tmp
		where	guid	=	@guid
		and		balqty	=	0
	end
	

	
	select	'Stock'		'wms_tmp_char1',
			@datefrom	'wms_datefrom',
			@dateto		'wms_dateto',
			@ouname		'wms_OUName',
			warehouse	'wms_WHCode',		
			whdesc		'wms_wh_desc',
			transdate	'wms_tmp_date1',
			refdocno	'wms_tmp_char2',
			reflineno	'wms_LineNo',
			refschno	'wms_SubLineNo',
			itemcode	'wms_ItemCode',
			case variant	when '##' then null else variant end			'wms_Variantcode',
			loi_itemdesc													'wms_ItemDesc',--CUBE_LIVE_WMS REPORT_00001
			case lotno	when '##' then null else lotno end			'wms_LotNo',
			recstkqty * dbo.uom_uomconvert_fn ('WHR',@ctxt_ouinstance,
												@tran_date,ucon_itemcode,ucon_variantcode,
												lov_stockuom,ucon_touom)	'wms_recQty',
			ucon_touom														'wms_recUOM',
			recstkqty														'wms_recstkQty',
			lov_stockuom													'wms_recstkuom',
			dbo.get_metadata_desc_fn('WHR','COMBO','STKSTS',
				stocksts,@ctxt_language)									'wms_StkStatus',
			case desstkqty when 0 then null else desstkqty * dbo.uom_uomconvert_fn ('WHR',@ctxt_ouinstance,
												@tran_date,ucon_itemcode,ucon_variantcode,
												lov_stockuom,ucon_touom) end	'wms_expQty',
			case desstkqty when 0 then null else ucon_touom	end					'wms_expUOM',
			case desstkqty when 0 then null else desstkqty	end				'wms_expstkQty',
			case desstkqty when 0 then null else lov_stockuom end				'wms_expstkuom',
			case (recstkqty - desstkqty) when 0 then null else (recstkqty - desstkqty)* dbo.uom_uomconvert_fn ('WHR',@ctxt_ouinstance,
												@tran_date,ucon_itemcode,ucon_variantcode,
												lov_stockuom,ucon_touom) end	'wms_excQty',
			case (recstkqty - desstkqty) when 0 then null else ucon_touom end	'wms_excUOM',
			case (recstkqty - desstkqty) when 0 then null else (recstkqty - desstkqty) end	'wms_excstkQty',
			case (recstkqty - desstkqty) when 0 then null else lov_stockuom	end		'wms_excstkuom'
			--dbo.get_metadata_desc_fn('WHR','COMBO',
			--	'TMODE',tranmode,@ctxt_language)							'wms_ModeOfTrans',
			--udfield1	'wms_UDField1',
			--trkcontno	'wms_TruckContNo',
			--dbo.sup_supname_fn(@lo_id,suppname)	'wms_SuppName'
	from wms_inv_stlegr_tmp(nolock)
	inner	Join	itm_loi_itemhdr(nolock)
	On		(loi_lo			= @lo_id
	and		loi_itemcode	= ItemCode)
	left outer join itm_lov_varianthdr (nolock)
	on		(ItemCode		= lov_ItemCode
	and		variant			= lov_variantcode)
	left outer join itm_ucon_conversion (nolock)
	on		(ucon_fromuom		= lov_stockuom
	and		ucon_itemcode		= lov_ItemCode
	and		ucon_variantcode	= lov_variantcode)
	where 	guid = @guid
	
	delete from wms_inv_stlegr_tmp
	where  	guid = @guid
		
	set nocount off
end
	


