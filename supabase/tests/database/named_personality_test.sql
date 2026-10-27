begin;
select plan(5);
select has_column('public','fish','personality_code','single named personality field exists');
select is(public.named_personality_codes('enthusiastic'), array['bold','curious'], 'enthusiastic mapping');
select is(public.named_personality_codes('gentle'), array['bold','lazy'], 'gentle mapping');
select is(public.named_personality_codes('cautious'), array['curious','shy'], 'cautious mapping');
select is(public.named_personality_codes('quiet'), array['lazy','shy'], 'quiet mapping');
select * from finish();
rollback;
